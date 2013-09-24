xquery version "1.0";

module namespace proc = "http://mustache.xq/processor";

(:~
: Choose a processor to use
:)

(: eXist-db :)
import module namespace impl = "http://mustache.xq/processor/impl/exist-db" at "impl/exist-db/impl.xqy";

(: MarkLogic :)
(: import module namespace impl = "http://mustache.xq/processor/impl/marklogic" at "impl/marklogic/impl.xqy"; :)


declare function proc:eval($query as xs:string) {
    impl:eval($query)
};

declare function proc:parse-with-fixes($unparsed as xs:string) as node()+ {
    impl:parse-with-fixes($unparsed)
};

declare function proc:log($messages as xs:string+) as empty() {
    impl:log($messages)
};

declare function proc:base64-encode($string as xs:string) as xs:base64Binary {
    impl:base64-encode($string)
};

declare function proc:base64-decode($base64 as xs:base64Binary) as xs:string {
    impl:base64-decode($base64)
};

declare function proc:unpath($string as xs:string) {
    impl:unpath($string)
};

declare function proc:serialize($node) as xs:string {
    impl:serialize($node)
};

declare function proc:hex-to-integer($hex as xs:string) as xs:integer {
    impl:hex-to-integer($hex)
};