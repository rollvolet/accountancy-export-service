import { query, update, sparqlEscapeString, sparqlEscapeDateTime, sparqlEscapeInt, sparqlEscapeFloat, sparqlEscapeUri, uuid } from 'mu'
import { querySudo, updateSudo } from '@lblod/mu-auth-sudo';
import parseISO from 'date-fns/parseISO'
import Invoice from './invoice'

BASE_URI = process.env.BASE_URI || 'http://data.rollvolet.be'

export fetchUserForSession = (session) ->
  result = await query """
    PREFIX muSession: <http://mu.semte.ch/vocabularies/session/>
    PREFIX foaf: <http://xmlns.com/foaf/0.1/>

    SELECT ?user
    WHERE {
      #{sparqlEscapeUri(session)} muSession:account ?account .
      ?user foaf:account ?account .
    } LIMIT 1
  """
  result.results.bindings[0]?.user?.value

export fetchInvoices = (fromNumber, untilNumber, isDryRun) ->
  dryRunFilter = if isDryRun then "" else "FILTER NOT EXISTS { ?invoice crm:bookingDate ?bookingDate . }"
  result = await query """
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX p2poDocument: <https://purl.org/p2p-o/document#>
    PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>
    PREFIX p2poPrice: <https://purl.org/p2p-o/price#>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX schema: <http://schema.org/>
    PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
    PREFIX prov: <http://www.w3.org/ns/prov#>

    SELECT ?invoice ?invoiceType ?uuid ?date ?number ?totalAmount ?vatRate ?vatCode (SUM(?arithmeticDepositAmount) as ?depositAmount) ?type ?dueDate ?customerNumber ?customerName ?customerType ?customerVatNumber ?street ?postalCode ?city ?countryCode
    WHERE {
      ?invoice a p2poDocument:E-Invoice, ?invoiceType ;
        mu:uuid ?uuid ;
        p2poInvoice:dateOfIssue ?date ;
        p2poInvoice:invoiceNumber ?number ;
        p2poInvoice:hasTotalLineNetAmount ?totalAmount .
      FILTER (?invoiceType != p2poDocument:E-Invoice)
      FILTER (?number >= #{sparqlEscapeInt(fromNumber)} && ?number <= #{sparqlEscapeInt(untilNumber)})
      #{dryRunFilter}
      ?case ?partOfCaseP ?invoice ; p2poPrice:hasVATCategoryCode ?vat .
      ?vat schema:value ?vatRate ; schema:identifier ?vatCode .
      VALUES ?partOfCaseP {
        ext:invoice
        ext:depositInvoice
      }
      ?invoice p2poInvoice:hasBuyer ?customer .
      ?customer vcard:hasUID ?customerNumber ;
        prov:hadPrimarySource/vcard:hasFamilyName ?customerName ;
        dct:type ?customerType .
      OPTIONAL { ?customer schema:vatID ?customerVatNumber . }
      OPTIONAL {
        ?customer vcard:hasAddress ?address .
        OPTIONAL { ?address vcard:hasStreetAddress ?street . }
        OPTIONAL { ?address vcard:hasPostalCode ?postalCode . }
        OPTIONAL { ?address vcard:hasLocality ?city . }
        OPTIONAL { ?address vcard:hasCountryName/schema:identifier ?countryCode . }
      }
      OPTIONAL { ?invoice dct:type ?type . }
      OPTIONAL { ?invoice p2poInvoice:paymentDueDate ?dueDate . }
      OPTIONAL {
        ?case ext:invoice ?invoice .
        ?case ext:depositInvoice ?depositInvoice .
        ?depositInvoice p2poInvoice:hasTotalLineNetAmount ?depositAmount .
        OPTIONAL { ?depositInvoice dct:type ?depositInvoiceType . }
        BIND(IF(?depositInvoiceType = p2poInvoice:E-CreditNote, ?depositAmount * -1, ?depositAmount) as ?arithmeticDepositAmount)
      }
    } GROUP BY ?invoice ?invoiceType ?uuid ?date ?number ?totalAmount ?vatRate ?vatCode ?type ?dueDate ?customerNumber ?customerName ?customerType ?customerVatNumber ?street ?postalCode ?city ?countryCode
    ORDER BY ?number
  """

  result.results.bindings.map (binding) -> Invoice.fromSparqlBinding(binding)

# Note: query pattern must be the same as the non-optional part of fetchInvoices
# in order to match the same set of invoices
export bookInvoices = (fromNumber, untilNumber) ->
  now = new Date()
  await update """
    PREFIX ext: <http://mu.semte.ch/vocabularies/ext/>
    PREFIX p2poDocument: <https://purl.org/p2p-o/document#>
    PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>
    PREFIX p2poPrice: <https://purl.org/p2p-o/price#>
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX schema: <http://schema.org/>
    PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>

    INSERT {
      ?invoice crm:bookingDate #{sparqlEscapeDateTime(now)} .
    }
    WHERE {
      ?invoice a p2poDocument:E-Invoice ;
        p2poInvoice:dateOfIssue ?date ;
        p2poInvoice:invoiceNumber ?number ;
        p2poInvoice:hasTotalLineNetAmount ?totalAmount .
      FILTER (?number >= #{sparqlEscapeInt(fromNumber)} && ?number <= #{sparqlEscapeInt(untilNumber)})
      FILTER NOT EXISTS { ?invoice crm:bookingDate ?bookingDate . }
      ?case ?partOfCaseP ?invoice ; p2poPrice:hasVATCategoryCode ?vat .
      ?vat schema:value ?vatRate ; schema:identifier ?vatCode .
      VALUES ?partOfCaseP {
        ext:invoice
        ext:depositInvoice
      }
      ?invoice p2poInvoice:hasBuyer/vcard:hasUID ?customerNumber .
    }
  """

export getInvoicelines = (uri) ->
  result = await query """
    PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>
    PREFIX schema: <http://schema.org/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>

    SELECT ?line ?amount
    WHERE {
      GRAPH ?g {
        <#{uri}> a p2poInvoice:E-FinalInvoice ;
          p2poInvoice:hasInvoiceLine ?line .
        ?line schema:amount ?amount
      }
    }
  """

  result.results.bindings.map (binding) -> { uri: binding.line.value, amount: binding.amount.value }

export getInvoicesWithDifferentTotalAmounts = () ->
  result = await querySudo """
    PREFIX p2poDocument: <https://purl.org/p2p-o/document#>
    PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX schema: <http://schema.org/>

    SELECT ?s ?amount ?number ?date ?source ?lineTotal WHERE {
      GRAPH ?g {
        ?s p2poInvoice:invoiceNumber ?number ;
          p2poInvoice:dateOfIssue ?date ;
          dct:source ?source ;
          p2poInvoice:hasTotalLineNetAmount ?amount .
        {
          SELECT ?s (SUM(?lineAmount) as ?lineTotal)
          WHERE {
            GRAPH ?g {
              ?s a p2poInvoice:E-FinalInvoice ; p2poInvoice:hasInvoiceLine ?line .
              ?line schema:amount ?lineAmount .
            }
          }
        }
        FILTER (ROUND(100 * ?lineTotal) != ROUND(100 * ?amount))
     }
  }
  """

  result.results.bindings.map (binding) ->
    uri: binding.s.value
    number: binding.number.value
    date: parseISO(binding.date.value)
    invoiceTotal: parseFloat(binding.amount.value)
    lineTotal: parseFloat(binding.lineTotal.value)

export updateInvoiceAmount = (uri, amount) ->
  await updateSudo """
    PREFIX p2poDocument: <https://purl.org/p2p-o/document#>
    PREFIX p2poInvoice: <https://purl.org/p2p-o/invoice#>

    DELETE {
      GRAPH ?g {
        #{sparqlEscapeUri(uri)} p2poInvoice:hasTotalLineNetAmount ?amount .
      }
    } INSERT {
      GRAPH ?g {
        #{sparqlEscapeUri(uri)} p2poInvoice:hasTotalLineNetAmount #{sparqlEscapeFloat(amount)} .
      }
    } WHERE {
      GRAPH ?g {
        #{sparqlEscapeUri(uri)} a p2poDocument:E-Invoice ;
          p2poInvoice:hasTotalLineNetAmount ?amount .
      }
    }
  """

export insertAccountancyExport = (fromNumber, untilNumber, type, files) ->
  id = uuid()
  uri = "#{BASE_URI}/accountancy-exports/#{id}"
  now = new Date()
  fileUris = files.map (file) -> sparqlEscapeUri(file)

  await update """
    PREFIX crm: <http://data.rollvolet.be/vocabularies/crm/>
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX prov: <http://www.w3.org/ns/prov#>
    PREFIX dct: <http://purl.org/dc/terms/>

    INSERT DATA {
      #{sparqlEscapeUri(uri)} a crm:AccountancyExport ;
        mu:uuid #{sparqlEscapeString(id)} ;
        dct:type #{sparqlEscapeUri(type)} ;
        prov:startedAtTime #{sparqlEscapeDateTime(now)} ;
        crm:fromNumber #{sparqlEscapeInt(fromNumber)} ;
        crm:untilNumber #{sparqlEscapeInt(untilNumber)} ;
        prov:generated #{fileUris.join(',')} .
    }
  """

  { uri, id, date: now }

export insertFile = (file) ->
  fileId = uuid()
  fileUri = "#{BASE_URI}/files/#{fileId}"
  dropFileUri = "share://#{file.name}"
  extension = file.name.substr(file.name.lastIndexOf('.') + 1)

  creatorStatement = if file.creator then "dct:creator #{sparqlEscapeUri(file.creator)} ;" else ''

  await update """
    PREFIX mu: <http://mu.semte.ch/vocabularies/core/>
    PREFIX nfo: <http://www.semanticdesktop.org/ontologies/2007/03/22/nfo#>
    PREFIX nie: <http://www.semanticdesktop.org/ontologies/2007/01/19/nie#>
    PREFIX dbpedia: <http://dbpedia.org/ontology/>
    PREFIX dct: <http://purl.org/dc/terms/>
    PREFIX dossier: <https://data.vlaanderen.be/ns/dossier#>
    PREFIX prov: <http://www.w3.org/ns/prov#>

    INSERT DATA {
      #{sparqlEscapeUri(fileUri)} a nfo:FileDataObject ;
        mu:uuid #{sparqlEscapeString(fileId)} ;
        nfo:fileName #{sparqlEscapeString(file.name)} ;
        dct:format #{sparqlEscapeString(file.format)} ;
        nfo:fileSize #{sparqlEscapeInt(file.size)} ;
        dbpedia:fileExtension #{sparqlEscapeString(extension)} ;
        nfo:fileCreated #{sparqlEscapeDateTime(file.created)} ;
        #{creatorStatement}
        dct:type #{sparqlEscapeUri(file.type)} .
      #{sparqlEscapeUri(dropFileUri)} a nfo:FileDataObject ;
        mu:uuid #{sparqlEscapeString(file.id)} ;
        nfo:fileName #{sparqlEscapeString(file.name)} ;
        dct:format #{sparqlEscapeString(file.format)} ;
        nfo:fileSize #{sparqlEscapeInt(file.size)} ;
        dbpedia:fileExtension #{sparqlEscapeString(extension)} ;
        nfo:fileCreated #{sparqlEscapeDateTime(file.created)} ;
        #{creatorStatement}
        nie:dataSource #{sparqlEscapeUri(fileUri)} .
    }
  """

  { uri: fileUri, id: fileId }
