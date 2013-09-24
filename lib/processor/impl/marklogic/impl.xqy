xquery version "1.0-ml";

module namespace impl = "http://mustache.xq/processor/impl/marklogic";

declare function impl:parse-with-fixes($unparsed as xs:string) as node()+ {
    xdmp:unquote($unparsed, "", "repair-full")
};

declare function impl:eval($query as xs:string) {
    xdmp:eval($query)
};

declare function impl:log($messages as xs:string+) as empty() {
    xdmp:log($messages)
};

declare function impl:base64-encode($string as xs:string) as xs:base64Binary {
    xdmp:base64-encode($string)
};

declare function impl:base64-decode($base64 as xs:base64Binary) as xs:string {
    xdmp:base64-decode($base64)
};

declare function impl:unpath($string as xs:string) {
    xdmp:unpath($string)
};

declare function impl:serialize($node) as xs:string {
    xdmp:quote($node)
};

declare function impl:hex-to-integer($hex as xs:string) as xs:integer {
    xdmp:hex-to-integer($hex)
};