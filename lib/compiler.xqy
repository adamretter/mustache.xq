(:
  XQuery Generator for mustache
:)
xquery version "3.0" ;
module namespace compiler = "compiler.xq" ;

import module namespace json = "http://marklogic.com/json" at "json.xqy" ;
import module namespace proc = "http://mustache.xq/processor" at "processor/processor.xqy";

declare function compiler:compile( $parseTree, $json ) {
 let $div := proc:parse-with-fixes( fn:concat( '&lt;div&gt;',
   fn:string-join(compiler:compile-xpath( $parseTree, json:jsonToXML( $json ) ), ''),  '&lt;/div&gt;') )
(: let $_ := proc:log(("#### OUTPUT ", $div)) :)
 return compiler:handle-escaping($div) } ;

declare function  compiler:compile-xpath( $parseTree, $json ) {
 let $_ := proc:log(("GOT", $parseTree, "WITH", $json,"")) return 
  compiler:compile-xpath( $parseTree, $json, 1, '' )
}; 

declare function compiler:compile-xpath( $parseTree, $json, $pos, $xpath ) { 
  for $node in $parseTree/node() 
(: let $_ := proc:log(("~~ NOW COMPILING NODE", proc:parse-with-fixes($node), "AT", $pos, "WITH XPATH", $xpath, "SUBSTITUTION WAS", compiler:compile-node( $node, $json, $pos, $xpath ))):)
  return compiler:compile-node( $node, $json, $pos, $xpath ) } ;

declare function compiler:compile-node( $node, $json, $pos, $xpath ) {
  typeswitch($node)
    case element(etag)    return
(:let $_ := proc:log(("FINAL STEP ON ETAG", proc:parse-with-fixes($node), "XPATH", $xpath, "POS", $pos)) return:)
    compiler:eval( $node/@name, $json, $pos, $xpath )
    case element(utag)    return compiler:eval( $node/@name, $json, $pos, $xpath, fn:false() )
    case element(rtag)    return 
      fn:string-join(compiler:eval( $node/@name, $json, $pos, $xpath, fn:true(), 'desc' ), " ")
    case element(static)  return $node /fn:string()
    case element(comment) return ()
    case element(inverted-section) return
      let $sNode := compiler:unpath( fn:string( $node/@name ) , $json, $pos, $xpath )
      return 
        if ( $sNode/@boolean = "true" ) 
        then ()
        else if ($sNode/@type = "array")
             then if (fn:exists($sNode/node())) 
             then () 
             else compiler:compile-xpath( $node, $json )
       else compiler:compile-xpath( $node, $json ) 
    case element(section) return
      let $sNode := compiler:unpath( fn:string( $node/@name ) , $json, $pos, $xpath )
(:let $_ := proc:log(("IN A SECTION ABOUT TO PROCESS", $sNode, "FOR", $node/@name)):)
      return 
        if ( $sNode/@boolean = "true" ) 
        then compiler:compile-xpath( $node, $json, $pos, $xpath ) 
        else
          if ( $sNode/@type = "array" )
          then (
(:let $_ := proc:log(("FOUND AN ARRAY")):)
            for $n at $p in $sNode/node()
(:let $_ := proc:log(fn:concat($p,": ", proc:parse-with-fixes($n))):)
            return compiler:compile-xpath( $node, $json, $p, fn:concat( $xpath, '/', fn:node-name($sNode), '/item' ) ) )
          else if($sNode/@type = "object") then 
(:let $_ := proc:log(("POSSIBLY AN OJBECT")) return:)
          compiler:compile-xpath( $node, $json, $pos, fn:concat( $xpath,'/', fn:node-name( $sNode ) ) ) else ()
    case text() return $node
    default return compiler:compile-xpath( $node, $json ) }; 

declare function compiler:eval( $node-name, $json, $pos ) { 
  compiler:eval($node-name, $json, $pos, '', fn:true() ) };
      
declare function compiler:eval( $node-name, $json, $pos, $xpath ) { 
  compiler:eval($node-name, $json, $pos, $xpath, fn:true() ) };

declare function compiler:eval( $node-name, $json, $pos, $xpath, $etag ) { 
 compiler:eval( $node-name, $json, $pos, $xpath, $etag, '' )
};

declare function compiler:eval( $node-name, $json, $pos, $xpath, $etag, $desc ) { 
(:let $_ := proc:log(("****** COMPILER EVAL ETAG", $etag )):)
  let $unpath :=  compiler:unpath( $node-name, $json, $pos, $xpath, $desc )
  return try {
    let $value := fn:string( proc:eval( proc:parse-with-fixes( $unpath ) ) )
    return if ($etag) 
    then fn:concat('{{b64:', proc:base64-encode($value), '}}') (: recursive mustache ftw :)
    else $value
  }  catch * ($errorcode , $description , $value) {
    $unpath
  }
};

declare function compiler:unpath( $node-name, $json, $pos, $xpath ) { 
  compiler:unpath( $node-name, $json, $pos, $xpath, '' )
};

declare function compiler:unpath( $node-name, $json, $pos, $xpath, $desc ) { 
  let $xp := fn:concat( '($json/json', $xpath, ')[', $pos, ']/',
    if ($desc='desc') then '/' else '', $node-name )
(:  let $_ := proc:log(("@@@@@ COMPILER UNPATH ", $node-name, "DESC", $desc, "SEARCHING FOR", $xp, "FOUND", proc:unpath($xp))):)
  return proc:unpath( $xp ) };

declare function compiler:handle-escaping( $div ) {
  for $n in $div/node()
  return compiler:handle-base64($n) };

declare function compiler:handle-base64( $node ) {
  typeswitch($node)
    case element()         return element {fn:node-name($node)} {
      for $a in $node/@*
      return attribute {fn:node-name($a)} {compiler:resolve-mustache-base64($a)}, 
      compiler:handle-escaping( $node )}
    case text()            return compiler:resolve-mustache-base64( $node)
    default                return compiler:handle-escaping( $node ) };

declare function compiler:resolve-mustache-base64( $text ) {
(: let $_ := proc:log(("BASE64ing", $text)) return :)
 fn:string-join( for $token in fn:tokenize($text, " ")
  return 
    if ( fn:matches( $token, '\{\{b64:(.+?)\}\}' ) )
    then 
      let $as := fn:analyze-string($token, '\{\{b64:(.+?)\}\}')
      let $b64    := $as//*:group[@nr=1]
      let $before := $as/*:match[1]/preceding::*:non-match[1]/fn:string()
      let $after  := $as/*:match[fn:last()]/following::*:non-match[1]/fn:string()
      return fn:string-join( ($before, for $decoded in proc:base64-decode( $b64 )
      let $executed := 
        if ( fn:matches( $decoded, "(&lt;|&gt;|&amp;|&quot;|&apos;)" ) )
        then fn:string($decoded)
        else fn:string(try { proc:eval( $decoded ) } catch * ($errorcode , $description , $value) { $decoded })
      return $executed, $after), '' )
    else if ( fn:matches( $token, '\{\{b64:\}\}' ) )
    then ""
    else $token, " ") };