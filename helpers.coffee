WINBOOKS_BOOK_YEAR = parseInt(process.env.WINBOOKS_BOOK_YEAR || '0101')
WINBOOKS_START_YEAR = parseInt(process.env.WINBOOKS_START_YEAR || '2015')

export formatDecimal = (number) ->
  parseFloat(number.toFixed(2)).toFixed(3) # formatted as 0.000

export formatName = (name) ->
  if name
    name.replaceAll(',', ' ').replaceAll(/[\r\n]/g, '-').substr(0, 40)
  else
    ''

export formatVatNumber = (vatNumber) ->
  if vatNumber and vatNumber.length >= 2 and vatNumber.substr(0, 2).toUpperCase()
    # VAT number used to be 9 numbers (like 000.000.000) but must be 10 (like 0000.000.000) now
    number = vatNumber.substr(2).trim().padStart(10, '0')
    "#{number.substr(0, 4)}.#{number.substr(4, 3)}.#{number.substr(7, 3)}"
  else
    ''

export getBookYear = (invoiceDate) ->
  invoiceYear = invoiceDate.getFullYear()
  '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'.charAt(invoiceYear - WINBOOKS_START_YEAR + 1)

export getPeriod = (invoiceDate) ->
  invoiceMonth = invoiceDate.getMonth() + 1
  startMonth = if WINBOOKS_BOOK_YEAR >= 100 then Math.floor(WINBOOKS_BOOK_YEAR / 100) else 0
  diff = invoiceMonth - startMonth + 1
  diff += 12 if diff <= 0
  "#{diff}".padStart(2, '0') # format with minimal 2 digits

export getAccount = (vatCode) ->
  switch
    when vatCode is '6' then '700000'
    when vatCode is '12' then '701000'
    when vatCode is '21' then '702000'
    when vatCode is 'vry' then '703000'
    when vatCode is 'exp' then '704000'
    when vatCode is 'm' then '705000'
    when vatCode is 'e' then '706000'
    when vatCode is '0' then '707000'
    else '??????'

export getVatCode = (vatCode) ->
  switch
    when vatCode is '6' then '211200'
    when vatCode is '12' then '211300'
    when vatCode is '21' then '211400'
    when vatCode is 'vry' then '244600'
    when vatCode is 'exp' then '231000'
    when vatCode is 'm' then '212000'
    when vatCode is 'e' then '221000'
    when vatCode is '0' then '211100'
    else '??????'

export getDocType = (vatCode) ->
  switch
    when ['6', '12', '21'].includes(vatCode) then '3'
    when ['vry', 'exp', 'm', 'e', '0'].includes(vatCode) then '4'
    else '?'
