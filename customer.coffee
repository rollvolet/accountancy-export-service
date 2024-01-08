import { formatName, formatVatNumber } from './helpers'

export default class Customer
  @fromSparqlBinding: (binding) ->
    customer = new Customer()
    customer.number = parseInt(binding['customerNumber'].value)
    customer.name = binding['customerName'].value
    customer.isCompany = binding['customerType'].value is 'http://www.w3.org/2006/vcard/ns#Organization'
    customer.vatNumber = binding['customerVatNumber']?.value
    customer.address =
      street: binding['street']?.value
      postalCode: binding['postalCode']?.value
      city: binding['city']?.value
      country: binding['countryCode']?.value

    customer

  export: ->
    line =
      Number: @number
      Type: '1'
      Name1: formatName(@name)
      Name2: ''
      CivName1: ''
      CivName2: ''
      Address1: formatName(@address.street)
      Address2: ''
      VATCat: if @isCompany then '1' else '3'
      Country: if @address.country then @address.country else '??'
      VatNumber: formatVatNumber(@vatNumber)
      PayCode: ''
      TelNumber: ''
      FaxNumber: ''
      BnkAccount: ''
      ZipCode: formatName(@address.postalCode)
      City: formatName(@address.city)
      DefitPost: ''
      Lang: ''
      Category: ''
      Central: ''
      VatCode: ''
      Currency: 'EUR'
      LastRemDev: ''
      LastRemDat: ''
      TotDeb1: '0.000'
      TotCre1: '0.000'
      TotDebTmp1: '0.000'
      TotCreTmp1: '0.000'
      TotDeb2: '0.000'
      TotCre2: '0.000'
      TotDebTmp2: '0.000'
      TotCreTmp2: '0.000'
      IsLocked: 'F'
      MemoType: ''
      IsDoc: 'T'
      F28150: ''

    line
