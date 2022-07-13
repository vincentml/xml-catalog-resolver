# XML Catalog Resolver in XQuery

This module provides an XML Catalog Resolver in the XQuery programming language. This module was created using [BaseX](https://basex.org/) version 9.7.3.

## Purpose

XML documents frequently contain a DOCTYPE declaration or a URI that points to a location that, for one reason or another, needs to be resolved to different location. XML Catalogs provide a standard way of configuring how a DOCTYPE or URI should resolve to a location (defined as a URI). XML Catalogs are similar to URL redirects but with fewer moving parts and specific features for XML.

XML Catalogs are super useful in a variety of scenarios. For example, if you are working with XML documents that contain a DOCTYPE that points to a DTD at a URL that no longer exists or is on a slow remote server you can use an XML Catalog to resolve the DOCTYPE to a local copy of the DTD that you have saved. It is easy to create an XML Catalog file that contains DOCTYPEs and URIs mapped to locations that you specify, set a few configuration options to use the XML Catalog, and then the XML Catalog helpfully resolves DOCTYPEs and URIs to the locations you specified.

Unfortunately, it can sometimes be challenging to get XML Catalogs to work. Java version 11 includes support for XML Catalogs, but older versions of Java (such as Java 8) require the addition of an XML Resolver and even then one may still find that XML Catalogs are not working. This XML Catalog Resolver XQuery module was created to work around problems with using XML Catalogs when running BaseX on older (or newer) versions of Java.

## Functions

This XQuery module provides the following functions.

### resolveDOCTYPE

Resolves the DOCTYPE declaration in an XML file using the XML Catalog. If the XML contains a DOCTYPE that matches an entry in the XML Catalog defined with a `public`, `system`, `systemSuffix`, or `rewriteSystem` element the DOCTYPE will be resolved to the location specified in the catalog entry. If no match is found in the XML Catalog then the XML will be returned unchanged.

Signature:

    resolver:resolveDOCTYPE($xml as xs:string, $catalog as xs:string) as xs:string

Parameters:

- $xml - XML document as a string
- $catalog - location of the XML Catalog file(s)

### resolveURI

Resolves a URI using the XML Catalog. If the URI matches an entry in the XML Catalog defined with a `uri`, `uriSuffix`, or `rewriteURI` element the URI will be resolved to the location specified in the catalog entry. If no match is found in the XML Catalog then the URI will be returned unchanged.

Signature:

    resolver:resolveURI($uri as xs:string, $catalog as xs:string) as xs:string

Parameters:

- $uri - the URI to resolve
- $catalog - location of the XML Catalog file(s)

### parse-xml

Resolves the DOCTYPE declaration in an XML file using the XML Catalog and then parses the XML.

Signature:

    resolver:parse-xml($xml as xs:string, $catalog as xs:string) as document-node()

Parameters:

- $xml - XML document as a string or a URI to an XML document
- $catalog - location of the XML Catalog file(s)

## XML Catalog File Location

The location of the XML Catalog file should be provided as an absolute file path. Multiple XML Catalog files can be used by providing a semicolon separated list of the file paths.

The location of the XML Catalog file can be written in an XQuery just like any other string.

    let $catalog := "C:\schemas\catalog.xml"

The absolute path to the catalog file can be determined relative to an XQuery file. The [File module](https://docs.basex.org/wiki/File_Module) provides functions that can help with identifying an absolute file path, for example:

    let $catalog := file:resolve-path('schemas/catalog.xml', file:base-dir())

There are also several ways to configure the location of the XML Catalog file(s) using BaseX configuration, Java system properties, and environment variables. With all of these methods, the value should be a semicolon separated list of absolute file paths.

- [catfile](https://docs.basex.org/wiki/Options#CATFILE) BaseX configuration option
- `org.basex.catfile` system property
- `javax.xml.catalog.files` system property
- `xml.catalog.files` system property
- `XML_CATALOG_FILES` environment variable

The following XQuery snippet can be used to get the location of the XML Catalog file(s) from any one of the above locations that has a value.

```xquery
let $catalog := head((
    db:option("catfile"),
    proc:property("org.basex.catfile"),
    proc:property("javax.xml.catalog.files"),
    proc:property("xml.catalog.files"),
    environment-variable("XML_CATALOG_FILES")
    )[.])
```

An XML Catalog file can import other XML Catalog file(s) using elements `nextCatalog`, `delegatePublic`, `delegateSystem`, or `delegateURI`.

## Example usage

```xquery
import module namespace resolver = "xml-catalog-resolver" at "https://raw.githubusercontent.com/vincentml/xml-catalog-resolver/main/xml-catalog-resolver.xqm";

let $catalog := head((
    db:option("catfile"),
    proc:property("org.basex.catfile"),
    proc:property("javax.xml.catalog.files"),
    proc:property("xml.catalog.files"),
    environment-variable("XML_CATALOG_FILES")
    )[.])
    
let $doc := "example.xml"

return resolver:parse-xml($doc, $catalog)
```

## Resources

- https://docs.basex.org/wiki/Catalog_Resolver
- https://xmlresolver.org/
- https://xerces.apache.org/xml-commons/components/resolver/resolver-article.html
- http://www.sagehill.net/docbookxsl/WriteCatalog.html
