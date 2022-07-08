# XML Catalog Resolver in XQuery

This module provides an XML Catalog Resolver in the XQuery programming language for use in [BaseX](https://basex.org/).

## Purpose

XML documents frequently contain a DOCTYPE declaration or a URI that points to a location that, for one reason or another, needs to be resolved to different location. XML Catalogs provide a standard way of configuring how a DOCTYPE or URI should resolve to a location (defined as a URI). XML Catalogs are similar to URL redirects but with fewer moving parts and specific features for XML.

XML Catalogs are super useful in a variety of scenarios. For example, if you are working with XML documents that contain a DOCTYPE that points to a URL that no longer exists or is on a slow remote server you can use an XML Catalog to resolve the DOCTYPE to a local copy of the DTD that you have saved. It is easy to create an XML Catalog file that contains DOCTYPEs and URIs mapped to locations that you specify, set a few configuration options to use the XML Catalog, and then the XML Catalog helpfully resolves DOCTYPEs and URIs to the locations you specified.

Unfortunately, getting XML Catalogs to work can sometimes be challenging. Java version 11 includes support for XML Catalogs, but older versions of Java (such as Java 8) require the addition of an XML Resolver and even then one may still find that XML Catalogs are not working. This XML Catalog Resolver XQuery module was created to work around problems with using XML Catalogs when running BaseX on older (or newer) versions of Java.

## Functions

This XQuery module provides the following functions.

### resolveDOCTYPE

Resolves the DOCTYPE declaration in an XML file using the XML Catalog. If the XML contains a DOCTYPE that matches an entry in the XML Catalog defined with a `public`, `system`, `systemSuffix`, or `rewriteSystem` element the DOCTYPE will be resolved to the location specified in the catalog entry. If no match is found in the XML Catalog then the XML will be returned unchanged.

Signature:

    resolver:resolveDOCTYPE($xml as xs:string, $catfile as xs:string) as xs:string

Parameters:

- $xml - XML document as a string
- $catfile - location of the XML Catalog file(s)

### resolveURI

Resolves a URI using the XML Catalog. If the URI matches an entry in the XML Catalog defined with a `uri`, `uriSuffix`, or `rewriteURI` element the URI will be resolved to the location specified in the catalog entry. If no match is found in the XML Catalog then the URI will be returned unchanged.

Signature:

    resolver:resolveURI($uri as xs:string, $catfile as xs:string) as xs:string

Parameters:

- $uri - the URI to resolve
- $catfile - location of the XML Catalog file(s)

### parse-xml

Resolves the DOCTYPE declaration in an XML file using the XML Catalog and then parses the XML.

Signature:

    resolver:parse-xml($xml as xs:string, $catfile as xs:string) as document-node()

Parameters:

- $xml - XML document as a string or a URI to an XML document
- $catfile - location of the XML Catalog file(s)

## XML Catalog File Location

The location of the XML Catalog file should be provided as an absolute file path.

    C:\schemas\catalog.xml

Multiple XML Catalog files can be used by providing a semicolon separated list of the file paths.

    C:\schemas\catalog1.xml;C:\schemas\catalog2.xml

An XML Catalog file can import other XML Catalog file(s) using elements `nextCatalog`, `delegatePublic`, `delegateSystem`, or `delegateURI`. This provides another way to use multiple XML Catalog files.

The location of the XML Catalog file can be written in an XQuery just like any other string.

    let $catfile := "C:\schemas\catalog.xml"

There are also several ways to configure the location of the XML Catalog file(s) using BaseX configuration, Java system properties, and environment variables. With all of these methods, the value should be a semicolon separated list of absolute file paths.

- [catfile](https://docs.basex.org/wiki/Options#CATFILE) BaseX configuration option
- `org.basex.catfile` system property
- `javax.xml.catalog.files` system property
- `xml.catalog.files` system property
- `XML_CATALOG_FILES` environment variable

The following example can be used to get the location of the XML Catalog file(s) from any one of the above that has a value.

    let $catfile := head((
        db:option("catfile"),
        proc:property("org.basex.catfile"),
        proc:property("javax.xml.catalog.files"),
        proc:property("xml.catalog.files"),
        environment-variable("XML_CATALOG_FILES")
        )[.])

## Example usage

```xquery
import module namespace resolver = "xml-catalog-resolver" at "https://raw.githubusercontent.com/vincentml/xml-catalog-resolver/main/xml-catalog-resolver.xqm";

let $catfile := head((
    db:option("catfile"),
    proc:property("org.basex.catfile"),
    proc:property("javax.xml.catalog.files"),
    proc:property("xml.catalog.files"),
    environment-variable("XML_CATALOG_FILES")
    )[.])
    
let $doc := "example.xml"

return resolver:parse-xml($doc, $catfile)
```
