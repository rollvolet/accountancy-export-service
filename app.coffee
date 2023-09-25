import { app, errorHandler } from 'mu'
import AccountancyExport from './accountancy-export'

app.post '/accountancy-exports', (req, res, next) ->
  if req.body.data?.attributes?['from-number']
    { 'from-number': fromNumber, 'until-number': untilNumber, type } = req.body.data.attributes
    untilNumber = fromNumber unless untilNumber
    accountancyExport = new AccountancyExport(fromNumber, untilNumber, type)

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

app.use(errorHandler)
