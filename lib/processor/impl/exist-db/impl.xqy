xquery version "1.0";

module namespace impl = "http://mustache.xq/processor/impl/exist-db";

import module namespace util = "http://exist-db.org/xquery/util";

declare function impl:parse-with-fixes($unparsed as xs:string) as node()+ {
    util:parse-html($unparsed)
};

declare function impl:eval($query as xs:string) {
    util:eval($query)
};

declare function impl:log($messages as xs:string+) as empty() {
    util:log("debug", fn:string-join($messages, ""))
};

declare function impl:base64-encode($string as xs:string) as xs:base64Binary {
    util:base64-encode($string)
};

declare function impl:base64-decode($base64 as xs:base64Binary) as xs:string {
    util:base64-decode($base64)
};

declare function impl:unpath($string as xs:string) {
    impl:eval($string)
};

declare function impl:serialize($node) as xs:string {
    util:serialize($node, ())
};

declare function impl:hex-to-integer($hex as xs:string) as xs:integer {
    util:base-to-integer($hex, 16)
};