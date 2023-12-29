import { getInvoicesWithDifferentTotalAmounts, updateInvoiceAmount } from './sparql'

export ensureInvoiceAmounts = () ->
  invoices = await getInvoicesWithDifferentTotalAmounts()
  if invoices.length
    console.log "Found #{invoices.length} invoices with an incorrect total amount"
    for invoice in invoices
      if invoice.invoiceTotal != invoice.lineTotal
        console.log "Invoice total amount is not up-to-date for invoice <#{invoice.uri}>. Expected #{invoice.invoiceTotal} but calculated #{invoice.lineTotal}. Going to update the amount in the database."
        await updateInvoiceAmount(invoice.uri, invoice.lineTotal)
    console.log "Finished updating invoices with an incorrect total amount"
  else
    console.log "No invoices found with an incorrect total amount"
