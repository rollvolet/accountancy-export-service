import formatDate from 'date-fns/format'
import parseISO from 'date-fns/parseISO'
import { formatDecimal, getBookYear, getPeriod, getAccount, getVatCode, getDocType } from './helpers'
import Customer from './customer'

WINBOOKS_DIARY = process.env.WINBOOKS_DIARY || 'VF1'

export default class Invoice
  @fromSparqlBinding: (binding) ->
    invoice = new Invoice()
    invoice.uri = binding['invoice'].value
    invoice.id = binding['uuid'].value
    invoice.invoiceDate = parseISO(binding['date'].value)
    invoice.number = parseInt(binding['number'].value)
    invoice.totalAmount = parseFloat(binding['totalAmount'].value)
    invoice.depositAmount = parseFloat(binding['depositAmount']?.value or '0.0')
    invoice.vatRate = parseFloat(binding['vatRate'].value)
    invoice.vatCode = binding['vatCode'].value
    invoice.isCreditNote = binding['type']?.value is 'https://purl.org/p2p-o/invoice#E-CreditNote'
    invoice.dueDate = parseISO(binding['dueDate'].value) if binding['dueDate']
    invoice.customer = Customer.fromSparqlBinding binding

    invoice

  validate: ->
    # TODO check invoice validity for export
    console.log "Invoice validation is not yet implemented"
    true

  export: ->
    bookYear = getBookYear(@invoiceDate)
    period = getPeriod(@invoiceDate)
    invoiceNumber = "#{@number}".padStart(5, '0') # format with minimal 5 digits
    invoiceDateStr = formatDate(@invoiceDate, 'yyyyMMdd')
    dueDateStr = formatDate(@dueDate or @invoiceDate, 'yyyyMMdd')

    amount = @totalAmount - @depositAmount
    vatAmount = amount * @vatRate / 100.0
    grossAmount = amount + vatAmount

    if @isCreditNote
      amount *= -1
      vatAmount *= -1
      grossAmount *= -1

    grossAmountSalesLine =
      DocType: '1'
      DBKCode: WINBOOKS_DIARY
      DBKType: '2'
      DocNumber: invoiceNumber
      DocOrder: '001'
      OPCode: ''
      AccountGL: '400000'
      AccountRP: "#{@customer.number}"
      BookYear: bookYear
      Period: period
      Date: invoiceDateStr
      DateDoc: invoiceDateStr
      DueDate: dueDateStr
      Comment: ''
      CommentText: ''
      Amount: '0.000'
      AmountEUR: formatDecimal(grossAmount)
      VATBase: formatDecimal(amount)
      VATCode: ''
      CurrAmount: '0.000'
      CurrCode: ''
      CurEURBase: '0.000'
      VATTax: formatDecimal(vatAmount)
      VATInput: ''
      CurrRate: '0.00000'
      RemindLev: '0'
      MatchNo: ''
      OldDate: '    '
      IsMatched: 'T'
      IsLocked: 'F'
      IsImported: 'F'
      IsPositve: 'T'
      IsTemp: 'F'
      MemoType: ' '
      IsDoc: 'F'
      DocStatus: ' '
      DICFrom: ''
      CODAKey: ''

    account = getAccount(@vatCode)
    vatCode = getVatCode(@vatCode)

    netAmountSalesLine =
      DocType: '3'
      DBKCode: WINBOOKS_DIARY
      DBKType: '2'
      DocNumber: invoiceNumber
      DocOrder: '002'
      OPCode: ''
      AccountGL: account
      AccountRP: "#{@customer.number}"
      BookYear: bookYear
      Period: period
      Date: invoiceDateStr
      DateDoc: invoiceDateStr
      DueDate: dueDateStr
      Comment: ''
      CommentText: ''
      Amount: '0.000'
      AmountEUR: formatDecimal(amount * -1)
      VATBase: '0.000'
      VATCode: ''
      CurrAmount: '0.000'
      CurrCode: ''
      CurEURBase: '0.000'
      VATTax: '0.000'
      VATInput: vatCode
      CurrRate: '0.00000'
      RemindLev: '0'
      MatchNo: ''
      OldDate: '    '
      IsMatched: 'T'
      IsLocked: 'F'
      IsImported: 'F'
      IsPositve: 'T'
      IsTemp: 'F'
      MemoType: ' '
      IsDoc: 'F'
      DocStatus: ' '
      DICFrom: ''
      CODAKey: ''

    docType = getDocType(@vatCode)

    vatLine =
      DocType: docType
      DBKCode: WINBOOKS_DIARY
      DBKType: '2'
      DocNumber: invoiceNumber
      DocOrder: 'VAT'
      OPCode: 'FIXED'
      AccountGL: if docType is '4' then '' else '451000'
      AccountRP: "#{@customer.number}"
      BookYear: bookYear
      Period: period
      Date: invoiceDateStr
      DateDoc: invoiceDateStr
      DueDate: dueDateStr
      Comment: ''
      CommentText: ''
      Amount: '0.000'
      AmountEUR: formatDecimal(vatAmount * -1)
      VATBase: formatDecimal(if @isCreditNote then amount else Math.abs(amount))
      VATCode: vatCode
      CurrAmount: '0.000'
      CurrCode: ''
      CurEURBase: '0.000'
      VATTax: '0.000'
      VATInput: ''
      CurrRate: '0.00000'
      RemindLev: '0'
      MatchNo: ''
      OldDate: '    '
      IsMatched: 'F'
      IsLocked: 'F'
      IsImported: 'F'
      IsPositve: 'T'
      IsTemp: 'F'
      MemoType: ' '
      IsDoc: 'F'
      DocStatus: ' '
      DICFrom: ''
      CODAKey: ''

    [ grossAmountSalesLine, netAmountSalesLine, vatLine ]
