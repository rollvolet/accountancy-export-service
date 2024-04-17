import { app, errorHandler, uuid } from 'mu'
import { CronJob } from 'cron'
import fetch from 'node-fetch'
import AccountancyExport from './accountancy-export'
import { fetchUserForSession, fetchUnexportedInvoices } from './sparql'
import { ensureInvoiceAmounts } from './batch-jobs'

INVOICE_AMOUNT_VALIDATION_FREQUENCY = process.env.INVOICE_AMOUNT_VALIDATION_FREQUENCY || '0 */30 * * * *' # every 30 minutes

CronJob.from
  cronTime: INVOICE_AMOUNT_VALIDATION_FREQUENCY
  onTick: () -> await fetch('http://localhost/invoice-amounts', { method: 'PUT' })
  start: true

app.post '/accountancy-exports', (req, res, next) ->
  session = req.get 'mu-session-id'
  next(new Error('Session header is missing')) unless session
  user = await fetchUserForSession(session)

  if req.body.data?.attributes?['from-number']
    { 'from-number': fromNumber, 'until-number': untilNumber, type } = req.body.data.attributes
    untilNumber = fromNumber unless untilNumber
    accountancyExport = new AccountancyExport(fromNumber, untilNumber, type, user)

    await accountancyExport.run()

    res.status(201).send(
      data:
        type: 'accountancy-exports'
        id: accountancyExport.id
        attributes:
          uri: accountancyExport.uri
          type: accountancyExport.type
          date: accountancyExport.date.toISOString()
          'from-number': accountancyExport.fromNumber
          'until-number': accountancyExport.untilNumber
    )
  else
    next(new Error('Invoice number range is missing'))

app.put '/invoice-amounts/', (req, res, next) ->
  ensureInvoiceAmounts() # don't await async task
  res.status(202).send()

app.get '/accountancy-export-warnings', (req, res, next) ->
  errors = await fetchUnexportedInvoices()

  data = errors.map (error) ->
    type: 'accountancy-export-warnings'
    id: uuid()
    relationships:
      invoice:
        data:
          type: if error.invoice.type is 'https://purl.org/p2p-o/invoice#E-FinalInvoice' then 'invoices' else 'deposit-invoices'
          id: error.invoice.id
      'accountancy-export':
        data:
          type: 'accountancy-exports'
          id: error.accountancyExport.id

  res.send
    data: data

app.use(errorHandler)
