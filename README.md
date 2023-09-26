# Accountancy export service
Microservice generating exports for the accountancy system

## Getting started
### Adding the service to your stack
Add the following snippet to your `docker-compose.yml` to include the accountancy export service in your project.

```yml
accountancy-export:
  image: rollvolet/accountancy-export-service
  volumes:
    - ./data/filedrop:/share
```

## Reference
### Configuration
The following environment variables can be configured on the service. 

- **WINBOOKS_DIARY** (default: `VF1`)
- **WINBOOKS_BOOK_YEAR** (default: `0101`)
- **WINBOOKS_START_YEAR** (default: `2015`)
- **BASE_URI** (default: `http://data.rollvolet.be`): base URI for newly generated resources

All environment variables are optional and have a sensible default value. All `WINBOOKS_`-prefixed variables are related to the accountancy system and may not be modified.

### API
#### POST /accountancy-exports
Trigger a new accountancy export.

##### Request
The request body contains the range of invoice numbers to generate an export for and a flag to indicate whether the export must be executed as dry run.

Possible values for `type` are `http://data.rollvolet.be/vocabularies/crm/DryRunAccountancyExport` or `http://data.rollvolet.be/vocabularies/crm/FinalAccountancyExport`. When executing a dry run invoices will be exported regardless their current booking state and will not be marked as 'booked to the accountancy system' at the end. This feature is useful for development and testing purposes.

```json
{
  "data": {
    "type": "accountancy-exports",
    "attributes": {
      "type": "http://data.rollvolet.be/vocabularies/crm/FinalAccountancyExport",
      "from-number": 301085,
      "until-number": 301096
    }
  }
}
```

##### Response
- `201 Created` if the export has been executed succesfully. The exported files are stored in the (mounted) `/share` volume. The response body will contain the newly created accountancy export.

