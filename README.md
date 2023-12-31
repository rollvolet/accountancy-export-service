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
- `201 Created` if the export has been executed succesfully. The export generates two CSV files, one containing invoices and another one containing customer information. The resulting files are stored in the (mounted) `/share` volume. The response body will contain the newly created accountancy export.

#### PUT /invoice-amounts
Endpoint that validates and corrects the total amount of invoices by calculating the sum of the invoicelines.

##### Response
- `202 Accepted` if the validation is triggered.

### Data model
#### Prefixes
| Prefix | URI                                                       |
|--------|-----------------------------------------------------------|
| crm    | http://data.rollvolet.be/vocabularies/crm/                |
| dct    | http://purl.org/dc/terms/                                 |
| prov   | http://www.w3.org/ns/prov#                                |
| nfo    | http://www.semanticdesktop.org/ontologies/2007/03/22/nfo# |

#### Accountancy export
##### Class
`crm:AccountancyExport` < `prov:Activity`
##### Properties
| Name         | Predicate            | Range                | Definition                                                                               |
|--------------|----------------------|----------------------|------------------------------------------------------------------------------------------|
| date         | `prov:startedAtTime` | `xsd:dateTime`       | Date/time the export started                                                             |
| type         | `dct:type`           | `rdf:Resource`       | Type of the export. One of `crm:FinalAccountancyExport` or `crm:DryRunAccountancyExport` |
| from-number  | `crm:fromNumber`     | `xsd:integer`        | Invoice number to start the export from                                                  |
| until-number | `crm:untilNumber`    | `xsd:integer`        | End of the invoice number range to run export for                                        |
| files        | `prov:generated`     | `nfo:FileDataObject` | Files generated by the export                                                                                         |
#### Export files
##### Class
`nfo:FileDataObject`
##### Properties
The files generated by an accountancy export job follow the regular data model of the [file-service](https://github.com/semtech/mu-file-service). They are linked to the accountancy export via `prov:generated`.

The files are enriched with a type (`dct:type`) containing one of the following values:
| File type            | URI                                                                      |
|----------------------|--------------------------------------------------------------------------|
| Invoice export file  | `http://data.rollvolet.be/concepts/6fbc15d2-11c0-4868-8b11-d15b8f1a3802`   |
| Customer export file | `http://data.rollvolet.be/concepts/7afecda8-f128-4043-a69c-a68cbaaedac5` |

