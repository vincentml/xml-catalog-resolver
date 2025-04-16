(:~ 
 : This module provides an XML Resolver for OASIS XML Catalogs entirely in XQuery.
 : Use this module to resolve the location a DTD specified in a DOCTYPE before parsing XML.
 : 
 : Tested with BaseX versions 9.7.3 and 11.5
 : May work in other XQuery processors.
 :
 : @author Vincent Lizzi
 : @see https://github.com/vincentml/xml-catalog-resolver
 : @see https://basex.org/
 : @see https://docs.basex.org/wiki/Options#CATFILE
 : @see https://xmlresolver.org/
 : @see https://xerces.apache.org/xml-commons/components/resolver/resolver-article.html
 : @see http://www.sagehill.net/docbookxsl/WriteCatalog.html
 :)
module namespace resolver = "xml-catalog-resolver";

import module namespace file = "http://expath.org/ns/file";

declare namespace map = "http://www.w3.org/2005/xpath-functions/map";

(:~ Namespace for OASIS XML Catalogs :)
declare namespace catalog = "urn:oasis:names:tc:entity:xmlns:xml:catalog";

(:~ regular expression to match space characters in XML DOCTYPE :)
declare variable $resolver:space := '[&#x20;&#x9;&#xD;&#xA;]+';

(: regular expression to match Name, which is defined as Name ::= NameStartChar (NameChar)* :)
declare variable $resolver:name := '[:_A-Za-z&#xC0;-&#xD6;&#xD8;-&#xF6;&#xF8;-&#x2FF;&#x370;-&#x37D;&#x37F;-&#x1FFF;&#x200C;-&#x200D;&#x2070;-&#x218F;&#x2C00;-&#x2FEF;&#x3001;-&#xD7FF;&#xF900;-&#xFDCF;&#xFDF0;-&#xFFFD;&#x10000;-&#xEFFFF;][:_\.\-0-9A-Za-z&#xb7;&#x0300;-&#x036F;&#x203F;-&#x2040;&#xC0;-&#xD6;&#xD8;-&#xF6;&#xF8;-&#x2FF;&#x370;-&#x37D;&#x37F;-&#x1FFF;&#x200C;-&#x200D;&#x2070;-&#x218F;&#x2C00;-&#x2FEF;&#x3001;-&#xD7FF;&#xF900;-&#xFDCF;&#xFDF0;-&#xFFFD;&#x10000;-&#xEFFFF;]*';

(:~ regular expression to match the beginning of an XML DOCTYPE up to the root element name :)
declare variable $resolver:doctype_start := '(<!DOCTYPE' || $resolver:space || $resolver:name || $resolver:space || ')';

(:~ regular expression to match an XML comment :)
declare variable $resolver:comment := '<!--((?:[&#x9;&#xA;&#xD;&#x20;-&#x2C;&#x2E;-&#xD7FF;&#xE000;-&#xFFFD;&#x10000;-&#x10FFFF;]|-[&#x9;&#xA;&#xD;&#x20;-&#x2C;&#x2E;-&#xD7FF;&#xE000;-&#xFFFD;&#x10000;-&#x10FFFF;])*)-->';

(:~ 
 : Parse XML Catalog and return a list of all catalog entries with URIs expanded.
 : URI expansion will be based on file paths relative to the XML Catalog file or 
 : the @xml:base attribute if present in the XML Catalog. 
 :
 : @param $catalog Semicolon-separated list of XML catalog files. Absolute file path works best. 
 :
 : @return Sequence of all entries from all XML Catalogs that were loaded.
 :)
declare function resolver:catalogEntries($catalog as xs:string) as element()* {
  for $cat in tokenize($catalog, ';\s*') return
  let $catxml := (# db:dtd false #) (# db:intparse true #) { doc(file:resolve-path($cat)) }
  let $catparent := file:parent($cat)
  for $e in $catxml//*
  let $base := 
    if ($e/ancestor-or-self::catalog:*/@xml:base) 
    then ($e/ancestor-or-self::catalog:*/@xml:base)[last()]/string() 
    else $catparent
  return typeswitch ($e)
  case 
    element(catalog:system) |
    element(catalog:systemSuffix) |
    element(catalog:public) |
    element(catalog:uri) |
    element(catalog:uriSuffix)
    return resolver:expandUri($e, $base)
  case 
    element(catalog:nextCatalog) | 
    element(catalog:delegatePublic) |
    element(catalog:delegateSystem) |
    element(catalog:delegateURI)
    return resolver:catalogEntries(file:resolve-path($e/@catalog, $base))
  case
    element(catalog:rewriteSystem) |
    element(catalog:rewriteURI)
    return $e
  default return ()
};


declare %private function resolver:expandUri($entry as element(), $base as xs:string) as element() {
  copy $c := $entry
  modify replace value of node $c/@uri with file:path-to-uri(file:resolve-path($entry/@uri, $base))
  return $c
};


declare function resolver:regexEscapeString($string as xs:string) as xs:string {
  $string => replace("([\|\\\{\}\(\)\[\]\^\$\+\*\?\.])", "\\$1")
};


(:~ 
 : Resolve XML DOCTYPE using XML Catalog. 
 : The system literal URI in the DOCTYPE will be replaced with location provided by the XML Catalog.
 : The replacement strategy uses regular expressions that closely adhere to the grammar that is defined in the W3C Recommendation.
 : No attempt has been made to skip text that looks like a DOCTYPE but isn't, such as a DOCTYPE that is inside a comment.
 :
 : @param $xml XML as a string
 : @param $catalog Semicolon-separated list of XML catalog files. Absolute file path works best. 
 :
 : @return XML string with DOCTYPE resolved using the XML Catalog. If no mapping is found then the string is returned unchanged.
 : 
 : @see https://www.w3.org/TR/xml/#NT-doctypedecl
 :)
declare function resolver:resolveDOCTYPE($xml as xs:string, $catalog as xs:string) as xs:string {
  let $cat := resolver:catalogEntries($catalog)
    
  return fold-left($cat, $xml, function($x, $c) {
    typeswitch ($c)
    case element(catalog:public) return 
      let $public := resolver:regexEscapeString($c/@publicId)
      let $match := $resolver:doctype_start || 'PUBLIC'  || $resolver:space || '("' || $public || '"|' || "'" || $public || "')"  || $resolver:space || "('[^']*'|" || '"[^"]*")'
      let $replace := '$1PUBLIC $2 "' || $c/@uri || '"'
      return replace($x, $match, $replace)
      
    case element(catalog:system) return
      let $system := resolver:regexEscapeString($c/@systemId)
      let $match := $resolver:doctype_start || "(PUBLIC" || $resolver:space || "(?:'[^']*'|""[^""]*"")|SYSTEM)" || $resolver:space || "('" || $system || "'|""" || $system || """)"
      let $replace := '$1$2 "' || $c/@uri || '"'
      return replace($x, $match, $replace)
      
    case element(catalog:systemSuffix) return
      let $system := resolver:regexEscapeString($c/@systemIdSuffix)
      let $match := $resolver:doctype_start || "(PUBLIC" || $resolver:space || "(?:'[^']*'|""[^""]*"")|SYSTEM)" || $resolver:space || "('[^']*" || $system || "'|""[^""]*" || $system || """)"
      let $replace := '$1$2 "' || $c/@uri || '"'
      return replace($x, $match, $replace)
      
    case element(catalog:rewriteSystem) return
      let $system := resolver:regexEscapeString($c/@systemIdStartString)
      let $match := $resolver:doctype_start || "(PUBLIC" || $resolver:space || "(?:'[^']*'|""[^""]*"")|SYSTEM)" || $resolver:space || "(?:'" || $system || "([^']*)'|""" || $system || "([^""]*)"")"
      let $replace := '$1$2 "' || $c/@rewritePrefix || '$3$4"'
      return replace($x, $match, $replace)

    default return $x
  })
};


(:~ 
 : Resolve a URI using XML Catalog.
 : 
 : @param $uri The URI to resolve
 : @param $catalog Semicolon-separated list of XML catalog files. Absolute file path works best.
 : 
 : @return The resolved URI. If no mapping is found in the XML Catalog the URI will be returned unchanged.
 :)
declare function resolver:resolveURI($uri as xs:string, $catalog as xs:string) as xs:string {
  let $cat := resolver:catalogEntries($catalog)
  return fold-left($cat, $uri, function($x, $c) {
    typeswitch ($c)
    case element(catalog:uri) return 
      if ($c/@name eq $uri) then string($c/@uri) else $x
    case element(catalog:uriSuffix) return
      if (ends-with($x, $c/@uriSuffix)) 
      then string($c/@uri) 
      else $x
    case element(catalog:rewriteURI) return
      if (starts-with($x, $c/@uriStartString)) 
      then concat($c/@rewritePrefix, substring-after($x, $c/@uriStartString)) 
      else $x
    default return $x
  })
};


(:~ 
 : Parse XML using XML Catalog
 :
 : @param $xml an XML string or file path to the XML file
 : @param $catalog Semicolon-separated list of XML catalog files. Absolute file path works best.
 :
 : @return parsed XML document
 :)
declare function resolver:parse-xml($xml as xs:string, $catalog as xs:string) as document-node() {
  let $temp := file:create-temp-file('xml-catalog-resolver', '.xml')
  let $raw := if ($xml castable as xs:anyURI) then unparsed-text($xml) else $xml
  let $resolved := resolver:resolveDOCTYPE($raw, $catalog)
  return (
    file:write-text($temp, $resolved),
    (# db:dtd true #) (# db:intparse false #) { doc($temp) },
    file:delete($temp)
  )
};


(:~ 
 : Parse XML using XML Catalog
 :
 : @param $xml an XML string or file path to the XML file
 : @param $catalog Semicolon-separated list of XML catalog files. Absolute file path works best.
 : @param $path File path to a location where the XML will be written before being parsed in order to control base-uri()
 :
 : @return parsed XML document
 :)
declare function resolver:parse-xml($xml as xs:string, $catalog as xs:string, $path as xs:string) as document-node() {
  let $raw := if ($xml castable as xs:anyURI) then unparsed-text($xml) else $xml
  let $resolved := resolver:resolveDOCTYPE($raw, $catalog)
  return (
    file:write-text($path, $resolved),
    (# db:dtd true #) (# db:intparse false #) { doc($path) }
  )
};


(:~
 : Modifies a DOCTYPE to remove a PUBLIC or SYSTEM reference to an external DTD.
 : If the DOCTYPE contains an internal DTD then the internal part will remain intact.
 : The intention for this function is to prevent loading an external DTD when it is
 : known that the DTD is not needed, and mainly for parsing XML Catalogs.
 : With BaseX parsing options set to INTPARSE=true and DTD=false this function is not needed.
 :
 : @param $xml XML as a string
 :
 : @return XML string with the DOCTYPE modified. If no PUBLIC or SYSTEM reference is present then the string is returned unchanged.
 : 
 : @see https://www.w3.org/TR/xml/#NT-doctypedecl
 : @see https://docs.basex.org/wiki/Options#INTPARSE
 : @see https://docs.basex.org/wiki/Options#DTD
 :)
declare function resolver:removeExternalDTD($xml as xs:string) as xs:string {
  let $match := $resolver:doctype_start || "(PUBLIC" || $resolver:space || "(?:'[^']*'|""[^""]*"")|SYSTEM)" || $resolver:space || "(?:'[^']*'|""[^""]*"")"
  return replace($xml, $match, "$1")
};


(:~ 
 : Read a DOCTYPE from XML and return details of the DOCTYPE
 : Read the DOCTYPE declaration in an XML file and return the PUBLIC and SYSTEM identifiers if present.
 : The returned value is a map that may contain keys doctype-public and doctype-system, 
 : and can be used to provide serialization parameters to functions such as fn:serialize and file:write.
 : 
 : @param $xml XML as a string
 : 
 : @return a map containing doctype-public and doctype-system if available
 :
 : @see https://docs.basex.org/main/Serialization
 : @see https://docs.basex.org/main/Standard_Functions#fn:serialize
 : @see https://docs.basex.org/main/File_Functions#file:write
 :)
declare function resolver:readDOCTYPE ($xml as xs:string) as map(xs:string, xs:string) {
  let $quotes := '^"|^''|"$|''$'
  let $match := $resolver:doctype_start || "(PUBLIC" || $resolver:space || "('[^']*'|""[^""]*"")|SYSTEM)" || $resolver:space || "('[^']*'|""[^""]*"")"
  let $clean := replace($xml, $resolver:comment, '')
  let $expand := analyze-string($clean, $match)
  let $public := $expand//fn:group[@nr="3"]/replace(., '^SYSTEM$|' || $quotes, '')
  let $system := $expand//fn:group[@nr="4"]/replace(., $quotes, '')
  return map:merge((
    if (string-length($public) gt 0) then map{'doctype-public': $public} else (),
    if (string-length($system) gt 0) then map{'doctype-system': $system} else ()
  ))
};
