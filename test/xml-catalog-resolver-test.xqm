(:~ 
 : Test suite for module xml-catalog-resolver
 :)
module namespace resolverTest = "xml-catalog-resolver/test";

import module namespace resolver = "xml-catalog-resolver" at "../xml-catalog-resolver.xqm";

declare namespace catalog = "urn:oasis:names:tc:entity:xmlns:xml:catalog";


declare %unit:test function resolverTest:regexEscapeString() {
  unit:assert-equals(resolver:regexEscapeString("\ ^ $ * + ? . ( ) | { } [ ]"), "\\ \^ \$ \* \+ \? \. \( \) \| \{ \} \[ \]")
};


declare %unit:test function resolverTest:catalogEntries() {
  let $base := file:base-dir()
  let $catalog := file:resolve-path("catalog1.xml", $base)
  let $exampledtd := file:path-to-uri(file:resolve-path("example.dtd", $base))
  let $entries := resolver:catalogEntries($catalog)
  return (
    unit:assert-equals($entries[1], <catalog:system systemId="https://example.org/example.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[2], <catalog:systemSuffix systemIdSuffix="example.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[3], <catalog:public publicId="-//EXAMPLE//DTD v1//EN" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[4], <catalog:uri name="https://example.org/example-v1.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[5], <catalog:uriSuffix uriSuffix="example.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[6], <catalog:system systemId="http://example.org/example2.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[7], <catalog:system systemId="http://example.org/example3.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[8], <catalog:system systemId="http://example.org/example4.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[9], <catalog:system systemId="http://example.org/example4.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[10], <catalog:system systemId="http://example.org/example4.dtd" uri="{$exampledtd}"/>),
    unit:assert-equals($entries[11], <catalog:rewriteSystem systemIdStartString="C:\" rewritePrefix="file:///C:/path/"/>),
    unit:assert-equals($entries[12], <catalog:rewriteURI uriStartString="C:\" rewritePrefix="file:///C:/path/"/>),
    unit:assert-equals($entries[13], <catalog:public publicId="-//EXAMPLE//DTD v2//EN" uri="file:///C:/base1/example.dtd"/>),
    unit:assert-equals($entries[14], <catalog:public publicId="-//EXAMPLE//DTD v3//EN" uri="file:///C:/base2/example.dtd" xml:base="file:///C:/base2/"/>)
  )
};

declare %unit:test function resolverTest:resolveDOCTYPE() {
  let $base := file:base-dir()
  let $catalog := file:resolve-path("catalog1.xml", $base)
  let $exampledtd := file:path-to-uri(file:resolve-path("example.dtd", $base))
  return (
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//DTD v1//EN" "not-mapped"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//DTD v1//EN" "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'public'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//DTD v1//EN'' ''not-mapped''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//DTD v1//EN'' "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'public'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "https://example.org/example.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'system'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//not mapped//EN'' ''https://example.org/example.dtd''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//not mapped//EN'' "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'system'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "https://example.org/example.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'system'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM ''https://example.org/example.dtd''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'system'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "path/to/example.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'systemSuffix'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//not mapped//EN'' ''path/to/example.dtd''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC ''-//EXAMPLE//not mapped//EN'' "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'systemSuffix'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "path/to/example.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'systemSuffix'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM ''path/to/example.dtd''><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "' || $exampledtd || '"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'systemSuffix'),

    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "C:\another.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//not mapped//EN" "file:///C:/path/another.dtd"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'rewriteSystem'),
    
    let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "C:\another.dtd"><example/>'
    let $exp := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "file:///C:/path/another.dtd"><example/>'
    let $result := resolver:resolveDOCTYPE($xml, $catalog)
    return unit:assert-equals($result, $exp, 'rewriteSystem')
    
  )
};


declare %unit:test function resolverTest:resolveURI() {
  let $base := file:base-dir()
  let $catalog := file:resolve-path("catalog1.xml", $base)
  let $exampledtd := file:path-to-uri(file:resolve-path("example.dtd", $base))
  return (
    let $uri := "https://example.org/example-v1.dtd"
    let $result := resolver:resolveURI($uri, $catalog)
    return unit:assert-equals($result, $exampledtd, "uri"),
    
    let $uri := "path/to/example.dtd"
    let $result := resolver:resolveURI($uri, $catalog)
    return unit:assert-equals($result, $exampledtd, "uriSuffix"),
    
    let $uri := "C:\file.txt"
    let $result := resolver:resolveURI($uri, $catalog)
    return unit:assert-equals($result, "file:///C:/path/file.txt", "rewriteURI"),
    
    let $uri := "http://not-mapped.org/"
    let $result := resolver:resolveURI($uri, $catalog)
    return unit:assert-equals($result, $uri, "not mapped")
  )
};


declare %unit:test function resolverTest:parse-xml() {
  let $base := file:base-dir()
  let $catalog := file:resolve-path("catalog1.xml", $base)
  let $examplexml := file:resolve-path("example.xml", $base)
  let $result := resolver:parse-xml($examplexml, $catalog)
  return unit:assert-equals($result, document{<example att="default">expansion from external DTD</example>})
  ,
  let $base := file:base-dir()
  let $catalog := file:resolve-path("catalog1.xml", $base)
  let $examplexml := file:resolve-path("example.xml", $base) => unparsed-text()
  let $result := resolver:parse-xml($examplexml, $catalog)
  return unit:assert-equals($result, document{<example att="default">expansion from external DTD</example>})
};


declare %unit:test function resolverTest:parse-xml3() {
  let $base := file:base-dir()
  let $catalog := file:resolve-path("catalog1.xml", $base)
  let $examplexml := file:resolve-path("example.xml", $base)
  let $tempDir := file:create-temp-dir('xml-catalog-resolver', 'test')
  let $tempFile := $tempDir || 'example.xml'
  let $result := resolver:parse-xml($examplexml, $catalog, $tempFile)
  return (
    unit:assert-equals($result, document{<example att="default">expansion from external DTD</example>}),
    unit:assert(file:exists($tempFile)),
    file:delete($tempDir, true())
  )
};


declare %unit:test function resolverTest:removeExternalDTD() {
  let $example := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE catalog PUBLIC "-//OASIS//DTD Entity Resolution XML Catalog V1.0//EN" "http://www.oasis-open.org/committees/entity/release/1.0/catalog.dtd" []><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $expected := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE catalog  []><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $result := resolver:removeExternalDTD($example)
  return unit:assert-equals($result, $expected),
  
  let $example := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE catalog SYSTEM "http://www.oasis-open.org/committees/entity/release/1.0/catalog.dtd" []><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $expected := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE catalog  []><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $result := resolver:removeExternalDTD($example)
  return unit:assert-equals($result, $expected),
  
  let $example := '<?xml version="1.0" encoding="UTF-8"?><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $expected := '<?xml version="1.0" encoding="UTF-8"?><catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"><uri name="https://example.com/file.txt" uri="file.txt"/></catalog>'
  let $result := resolver:removeExternalDTD($example)
  return unit:assert-equals($result, $expected)
};


declare %unit:test function resolverTest:readDOCTYPE () {
  let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example SYSTEM "https://example.org/example.dtd"><example/>'
  let $expected := map{
    'doctype-system': 'https://example.org/example.dtd'
  }
  let $result := resolver:readDOCTYPE($xml)
  return unit:assert-equals($result, $expected),
  
  let $xml := "<?xml version='1.0' encoding='UTF-8'?><!DOCTYPE example SYSTEM 'https://example.org/example.dtd'><example/>"
  let $expected := map{
    'doctype-system': 'https://example.org/example.dtd'
  }
  let $result := resolver:readDOCTYPE($xml)
  return unit:assert-equals($result, $expected),
  
  let $xml := '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE example PUBLIC "-//EXAMPLE//DTD v1//EN" "https://example.org/example.dtd"><example/>'
  let $expected := map{
    'doctype-public': '-//EXAMPLE//DTD v1//EN',
    'doctype-system': 'https://example.org/example.dtd'
  }
  let $result := resolver:readDOCTYPE($xml)
  return unit:assert-equals($result, $expected),
  
  let $xml := "<?xml version='1.0' encoding='UTF-8'?><!DOCTYPE example PUBLIC '-//EXAMPLE//DTD v1//EN' 'https://example.org/example.dtd'><example/>"
  let $expected := map{
    'doctype-public': '-//EXAMPLE//DTD v1//EN',
    'doctype-system': 'https://example.org/example.dtd'
  }
  let $result := resolver:readDOCTYPE($xml)
  return unit:assert-equals($result, $expected),
  
  let $xml := "<?xml version='1.0' encoding='UTF-8'?><example/>"
  let $expected := map{}
  let $result := resolver:readDOCTYPE($xml)
  return unit:assert-equals($result, $expected),
  
  let $xml := '<?xml version="1.0" encoding="UTF-8"?><!-- <!DOCTYPE example PUBLIC "-//COMMENTED OUT//DTD v1//EN" "https://example.org/commented-out.dtd"> --><!DOCTYPE example PUBLIC "-//EXAMPLE//DTD v1//EN" "https://example.org/example.dtd"><!-- <!DOCTYPE example PUBLIC "-//COMMENTED OUT//DTD v1//EN" "https://example.org/commented-out.dtd"> --><example/>'
  let $expected := map{
    'doctype-public': '-//EXAMPLE//DTD v1//EN',
    'doctype-system': 'https://example.org/example.dtd'
  }
  let $result := resolver:readDOCTYPE($xml)
  return unit:assert-equals($result, $expected)
  
};