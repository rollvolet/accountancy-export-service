# Accountancy export service
Microservice generating exports for the accountancy system

## Getting started
### Adding the service to your stack
Add the following snippet to your `docker-compose.yml` to include the accountancy export service in your project.

```yml
accountancy-export:
  image: rollvolet/accountancy-export-service
```

## Reference
### API
#### POST /accountancy-exports
Trigger a new accountancy export.

##### Request
The request body contains the range of invoice numbers to generate an export for and a flag to indicate whether the export must be executed as dry run (i.e. the invoices will not be flagged as 'registered in the accountancy system').

```json
{
  "data": {
    "type": "accountancy-exports",
    "attributes": {
      "date": "20230825T09:04:38Z",
      "is-dry-run": false,
      "from-number": 301085,
      "until-number": 301096
    }
  }
}
```

##### Response
- `204 No Content` if the export has been executed succesfully. The exported files are stored on a configured location.
