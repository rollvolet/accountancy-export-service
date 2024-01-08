import { uuid } from 'mu'
import { stringify as stringifyCsv } from 'csv-stringify/sync'
import * as fs from 'node:fs/promises'
import uniqBy from 'lodash.uniqby'
import sortBy from 'lodash.sortby'
import { insertAccountancyExport, insertFile, fetchInvoices, bookInvoices } from './sparql'

INVOICE_EXPORT_FILE_TYPE = 'http://data.rollvolet.be/concepts/6fbc15d2-11c0-4868-8b11-d15b8f1a3802'
CUSTOMER_EXPORT_FILE_TYPE = 'http://data.rollvolet.be/concepts/7afecda8-f128-4043-a69c-a68cbaaedac5'

export default class AccountancyExport
  constructor: (@fromNumber, @untilNumber, @type, @creator) ->
    @isDryRun = @type is 'http://data.rollvolet.be/vocabularies/crm/DryRunAccountancyExport'

  run: ->
    invoices = await fetchInvoices(@fromNumber, @untilNumber, @isDryRun)
    customers = sortBy uniqBy(invoices.map((invoice) -> invoice.customer), 'number'), 'number'

    if @isDryRun
      console.log("Starting dry run of accountancy export. Simulating booking of #{invoices.length} invoices and #{customers.length} customers")
    else
      console.log("Starting accountancy export. #{invoices.length} invoices and #{customers.length} customers will be booked.")

    invoiceExportLines = await Promise.all(
      invoices.map (invoice) ->
        isValid = await invoice.validate()
        if (isValid)
          lines = invoice.export()
          console.log("Exported invoice #{invoice.number}")
          lines
        else
          console.log("Invoice #{invoice.number} is not valid for export")
          []
    )
    invoiceExportLines = invoiceExportLines.flat()
    csv = @serializeCsv invoiceExportLines
    invoiceFile = await @writeFile csv, INVOICE_EXPORT_FILE_TYPE

    customerExportLines = customers.map (customer) ->
      line = customer.export()
      console.log("Exported customer #{customer.number}")
      line
    csv = @serializeCsv customerExportLines
    customerFile = await @writeFile csv, CUSTOMER_EXPORT_FILE_TYPE

    await @save [invoiceFile.uri, customerFile.uri]
    await @book() unless @isDryRun

  serializeCsv: (lines) ->
    stringifyCsv lines,
      delimiter: ','
      quote: false
      header: false

  writeFile: (content, type) ->
    fileId = uuid()
    file =
      id: fileId
      name: "#{fileId}.csv"
      format: 'text/csv'
      created: new Date()
      creator: @creator
      type: type
    path = "/share/#{file.name}"
    await fs.writeFile path, content
    stats = await fs.stat path
    file.size = stats.size
    await insertFile file

  save: (files) ->
    { @uri, @id, @date } = await insertAccountancyExport(@fromNumber, @untilNumber, @type, files)

  book: ->
    await bookInvoices(@fromNumber, @untilNumber)
