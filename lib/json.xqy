(:
  Copyright Ryan Grimm (@isubiker)
  Source from github.com/isubiker/mljson

  Please refer to that project for improvements that require changes to this file.
:)

xquery version "3.0";
module namespace json="http://marklogic.com/json";

import module namespace proc = "http://mustache.xq/processor" at "processor/processor.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

(:
XXX:
    * Sanitize element names
    * Escape XML chars
    * Convert wide encoded unicode chars: \uFFFF\uFFFF
    * Convert \n to newlines
:)
declare function json:jsonToXML($json){ json:jsonToXML( $json, fn:true() ) };
declare function json:jsonToXML(
    $json as xs:string,
    $asXML as xs:boolean
)
{
    let $json-state := json:_create-state()
    let $bits := string-to-codepoints(replace($json, "\n", ""))
    let $json-bits := for $bit in $bits return codepoints-to-string($bit)
    let $typeBits := json:getType($json-bits, 1)
    let $type := $typeBits[1]
    let $typeEndLocation := $typeBits[2]
    let $location :=
        if($type = ("object", "array", "string", "number"))
        then 1
        else $typeEndLocation
    let $xmlString := string-join((json:typeToElement("json", $type), json:_get-values-from-result(json:dispatch($json-state, $json-bits, $location)), "</json>"), "")
    return
        if($asXML)
        then proc:parse-with-fixes($xmlString)
        else $xmlString
};

declare function json:dispatch(
    $json-state as element(json:state),
    $json-bits as xs:string*,
    $location as xs:integer
) as  element(json:fn-results)
{
    let $currentBit := $json-bits[$location]
    where exists($currentBit)
    return
        if($currentBit eq "{") then
            json:startObject($json-state, $json-bits, $location)
        
        else if($currentBit eq "}") then
            json:endObject($json-state, $json-bits, $location)
        
        else if($currentBit eq ":") then
            json:buildObjectValue($json-state, $json-bits, $location + 1)
            
        else if($currentBit eq "[") then
            json:startArray($json-state, $json-bits, $location)
            
        else if($currentBit eq "]") then
            json:endArray($json-state, $json-bits, $location)
            
        else if($currentBit eq "," and json:_peek-type-stack($json-state) eq "object") then
            let $fn-result := json:endObjectKey($json-state) return
                let $fn-result-2 := json:startObjectKey(json:_get-state-from-result($fn-result), $json-bits, $location + 1) return
                    json:_merge-result($fn-result, $fn-result-2)
        
        else if($currentBit eq "," and json:_peek-type-stack($json-state) eq "array") then
            let $result := json:endArrayItem() return
                let $fn-result := json:startArrayItem($json-state, $json-bits, $location + 1) return
                    json:_pack-result(json:_get-state-from-result($fn-result), ($result, json:_get-values-from-result($fn-result)))
        
        else if($currentBit eq """") then
            let $result := json:readCharsUntil($json-bits, $location + 1, """")[2] return
                json:_pack-result($json-state, $result)
        else
            (: XXX - Encode unicode :)
            if($currentBit eq "\") then
                json:dispatch($json-state, $json-bits, $location + 2)
            else
                json:dispatch($json-state, $json-bits, $location + 1)
};

declare
    %private
function json:_create-state() as element(json:state) {
    <json:state>
        <json:type-stack/>
        <json:key-object-stack/>
    </json:state>
};

declare
    %private
function json:_push-type-stack($json-state as element(json:state), $type as xs:string) as element(json:state) {
    <json:state>
        <json:type-stack>
            { $json-state/json:type-stack/json:entry }
            <json:entry>{$type}</json:entry>
        </json:type-stack>
        { $json-state/json:key-object-stack }
    </json:state>
};

declare
    %private
function json:_peek-type-stack($json-state as element(json:state)) as element(json:entry)? {
    $json-state/json:type-stack/json:entry[last()]
};

(: removes the top-most element from the stack :)
declare
    %private
function json:_skim-type-stack($json-state as element(json:state)) as element(json:state)? {
    <json:state>
        <json:type-stack>
            { $json-state/json:type-stack/json:entry[position() ne last()] }
        </json:type-stack>
        { $json-state/json:key-object-stack }
    </json:state>
};

declare
    %private
function json:_push-key-object-stack($json-state as element(json:state), $key-object as xs:string) as element(json:state) {
    <json:state>
        { $json-state/json:type-stack }
        <json:key-object-stack>
            { $json-state/json:key-object-stack/json:entry }
            <json:entry>{$key-object}</json:entry>
        </json:key-object-stack>
    </json:state>
};

declare
    %private
function json:_peek-key-object-stack($json-state as element(json:state)) as element(json:entry)? {
    $json-state/json:key-object-stack/json:entry[last()]
};

(: removes the top-most element from the stack :)
declare
    %private
function json:_skim-key-object-stack($json-state as element(json:state)) as element(json:state)? {
    <json:state>
        { $json-state/json:type-stack }
        <json:key-object-stack>
            { $json-state/json:key-object-stack/json:entry[position() ne last()] }
        </json:key-object-stack>
    </json:state>
};

declare
    %private
function json:_get-state-from-result($json-result as element(json:fn-result)) as element(json:state) {
    $json-result/json:state
};

declare
    %private
function json:_get-values-from-result($json-result as element(json:fn-result)) as xs:string* {
    for $json-value in $json-result/json:value return
        string($json-value)
};

declare
    %private
function json:_pack-result($json-state as element(json:state), $values as xs:string*) as element(json:fn-result) {
    <json:fn-result>
    {
        $json-state,
        for $value in $values return
            <json:value>{$value}</json:value>
    }
    </json:fn-result>
};

declare
    %private
function json:_merge-result($fn-result as element(json:fn-result), $fn-result-2 as element(json:fn-result)) as element(json:result) {
    json:_pack-result(json:_get-state-from-result($fn-result-2), (json:_get-values-from-result($fn-result), json:_get-values-from-result($fn-result)))
};

(: Javascript object handling :)

declare function json:startObject(
    $json-state as element(json:state),
    $json-bits as xs:string*,
    $location as xs:integer
) as element(json:fn-result)
{
    let $location := json:readCharsUntilNot($json-bits, $location + 1, " ")
    return
        if($json-bits[$location] eq "}") then
            let $json-state := json:_push-type-stack($json-state, "emptyobject") return
                json:endObject($json-state, $json-bits, $location)
        else
            let $json-state := json:_push-type-stack($json-state, "object") return
                json:startObjectKey($json-state, $json-bits, $location)
};

declare function json:endObject(
    $json-state as element(json:state),
    $json-bits as xs:string*,
    $location as xs:integer
) as element(json:fn-result)
{
    let $isEmpty := json:_peek-type-stack($json-state) eq "emptyobject"
    let $json-state := json:_skim-type-stack($json-state) return
        if($isEmpty) then 
            json:dispatch($json-state, $json-bits, $location + 1)
        else 
            let $fn-result := json:endObjectKey($json-state) return
                let $fn-result-2 := json:dispatch(json:_get-state-from-result($fn-result), $json-bits, $location + 1) return
                    json:_merge-result($fn-result, $fn-result-2)
};

declare function json:startObjectKey(
    $json-state as element(json:state),
    $json-bits as xs:string*,
    $location as xs:integer
) as element(json:fn-result)
{
    let $location := json:readCharsUntilNot($json-bits, $location, " ")

    let $valueBits := 
        if($json-bits[$location] eq """")
        then json:readCharsUntil($json-bits, $location + 1, """")
        else json:readCharsUntil($json-bits, $location, ":")
    let $location :=
        if($json-bits[$location] eq """")
        then $valueBits[1] + 1
        else $valueBits[1]
    let $keyName := $valueBits[2]

    let $typeBits := json:getType($json-bits, $location + 1)
    let $type := $typeBits[1]
    
    let $json-state := json:_push-key-object-stack($json-state, $keyName) return
    
        let $result := json:typeToElement($keyName, $type) return
            
            let $fn-result :=
                if($type = ("null", "boolean:true", "boolean:false")) then
                    json:dispatch($json-state, $json-bits, $typeBits[2])
                else
                    json:dispatch($json-state, $json-bits, $location)
            return
                json:_pack-result(json:_get-state-from-result($fn-result), ($result, json:_get-values-from-result($fn-result)))
};

declare function json:endObjectKey(
    $json-state as element(json:state)
) as element(json:fn-result)
{
    let $latestObjectName := json:_peek-key-object-stack($json-state)
    let $json-state := json:_skim-key-object-stack($json-state)
    let $result := concat("</", $latestObjectName, ">") return
        json:_pack-result($json-state, $result)
};

declare function json:buildObjectValue(
    $json-state as element(json:state),
    $json-bits as xs:string*,
    $location as xs:integer
) as element(json:fn-result)
{
    let $location := json:readCharsUntilNot($json-bits, $location, " ")
    let $currentBit := $json-bits[$location]
    return
        if($currentBit eq ("[", "{") (:":))
        then json:dispatch($json-state, $json-bits, $location)
        else
            let $deepValues :=
                if($currentBit eq """")
                then json:readCharsUntil($json-bits, $location + 1, ("""", "}"))
                else json:readCharsUntil($json-bits, $location, (",", "}"))
            let $location :=
                if($currentBit eq """")
                then $deepValues[1] + 1
                else $deepValues[1]
            let $normalizedValue :=
                if($currentBit eq """")
                then $deepValues[2]
                else normalize-space($deepValues[2])
            return
                let $result := $normalizedValue return 
                    let $fn-result := json:dispatch($json-state, $json-bits, $location) return
                        json:_pack-result(json:_get-state-from-result($fn-result), ($result, json:_get-values-from-result($fn-result)))
};


(: Javascript array handling :)

declare function json:startArray(
    $json-state as element(json:state),
    $json-bits as xs:string*,
    $location as xs:integer
) as element(json:fn-result)
{
    let $location := json:readCharsUntilNot($json-bits, $location + 1, " ")
    return
        if($json-bits[$location] eq "]")then
            let $json-state := json:_push-type-stack($json-state, "emptyarray") return
                json:endArray($json-state, $json-bits, $location)
        else
            let $json-state := json:_push-type-stack($json-state, "array") return
                json:startArrayItem($json-state, $json-bits, $location)
};

declare function json:endArray(
    $json-state as element(json:state),
    $json-bits as xs:string*,
    $location as xs:integer
) as element(json:fn-result)
{
    let $isEmpty := json:_peek-type-stack($json-state) eq "emptyarray"
    let $json-state := json:_skim-type-stack($json-state)
    return
        if($isEmpty)then
            json:dispatch($json-state, $json-bits, $location + 1)
        else
            let $result := json:endArrayItem() return
                let $fn-result := json:dispatch($json-state, $json-bits, $location + 1) return
                    json:_pack-result(json:_get-state-from-result($fn-result), ($result, json:_get-values-from-result($fn-result)))
};

declare function json:startArrayItem(
    $json-state as element(json:state),
    $json-bits as xs:string*,
    $location as xs:integer
) as element(json:fn-result)
{
    let $location := json:readCharsUntilNot($json-bits, $location, " ")
    let $typeBits := json:getType($json-bits, $location)
    let $type := $typeBits[1]
    let $typeEndLocation := $typeBits[2]
    return
        
        let $result := json:typeToElement("item", $type) return
        
            let $fn-result :=
                if($type = ("null", "boolean:false", "boolean:true")) then
                    json:dispatch($json-state, $json-bits, $typeEndLocation)
                else if($type = ("object", "array")) then
                    json:dispatch($json-state, $json-bits, $location)
                else
                    let $valueBits := 
                        if($json-bits[$location] eq """") then
                            json:readCharsUntil($json-bits, $location + 1, ("""", "]"))
                        else
                            json:readCharsUntil($json-bits, $location, (",", "]"))
                    let $location :=
                        if($json-bits[$location] eq """") then
                            $valueBits[1] + 1
                        else
                            $valueBits[1]
                    return
                        let $int-result := $valueBits[2] return
                            let $int-fn-result := json:dispatch($json-state, $json-bits, $location) return
                                json:_pack-result(json:_get-state-from-result($int-fn-result), ($int-result, json:_get-values-from-result($int-fn-result)))
                        
            return
                json:_pack-result(json:_get-state-from-result($fn-result), ($result, json:_get-values-from-result($fn-result)))
};

declare function json:endArrayItem(
) as xs:string*
{
    "</item>"
};


(: Helper functions :)

declare function json:getType(
    $json-bits as xs:string*,
    $location as xs:integer
)
{
    let $location := json:readCharsUntilNot($json-bits, $location, " ")
    let $currentBit := $json-bits[$location]
    return
        if($currentBit eq """")
        then "string"
        else if($currentBit eq "[")
        then "array"
        else if($currentBit eq "{" (:":))
        then "object"
        else if(string-join($json-bits[($location to $location + 3)], "") eq "null")
        then ("null", $location + 4)
        else if(string-join($json-bits[($location to $location + 3)], "") eq "true")
        then ("boolean:true", $location + 4)
        else if(string-join($json-bits[($location to $location + 4)], "") eq "false")
        then ("boolean:false", $location + 5)
        else "number"
};

declare function json:typeToElement(
    $elementName as xs:string,
    $type as xs:string
) as xs:string
{
    if($type eq "null")
    then concat("<", $elementName, " type='null'>")
    else if($type eq "boolean:true")
    then concat("<", $elementName, " boolean='true'>")
    else if($type eq "boolean:false")
    then concat("<", $elementName, " boolean='false'>")
    else concat("<", $elementName, " type='", $type, "'>")
};

declare function json:readCharsUntil(
    $json-bits as xs:string*,
    $location as xs:integer,
    $stopChars as xs:string+
) as xs:string*
{
    let $unescapedUnicode := 
        if($json-bits[$location] eq "\" and $json-bits[$location + 1] eq "u")then
            let $hex := string-join($json-bits[($location + 2 to $location + 5)], "")
            return
                codepoints-to-string(proc:hex-to-integer($hex))
        else()
    
    let $escaped := $json-bits[$location] eq "\" and $json-bits[$location + 1] ne "u"
    
    let $location :=
        if($json-bits[$location] eq "\") then 
            if($json-bits[$location + 1] eq "u") then
                $location + 5
            else
                $location + 1
        else $location
        
    let $currentBit := ($unescapedUnicode, $json-bits[$location])[1]
    let $currentBit :=
        if($currentBit eq "<")
        then "&amp;lt;"
        else if($currentBit eq "&amp;")
        then "&amp;amp;"
        else $currentBit
    return
        if($currentBit = $stopChars and not($escaped))
        then ($location, "")
        else 
            let $deepValues := json:readCharsUntil($json-bits, $location + 1, $stopChars)
            let $newLocation := $deepValues[1]
            let $value := $deepValues[2]
            return ($newLocation, concat($currentBit, $value))
};

declare function json:readCharsUntilNot(
    $json-bits as xs:string*,
    $location as xs:integer,
    $ignoreChar as xs:string
) as xs:integer
{
    if($json-bits[$location] ne $ignoreChar)
    then $location
    else json:readCharsUntilNot($json-bits, $location + 1, $ignoreChar)
};

declare function json:xmlToJson(
    $element as element()
) as xs:string
{
    json:processElement($element)
};

declare function json:processElement(
    $element as element()
) as xs:string
{
    if($element/@type = "object")
    then json:outputObject($element)
    else if($element/@type = "array")
    then json:outputArray($element)
    else if($element/@type = "null")
    then "null"
    else if(exists($element/@boolean))
    then xs:string($element/@boolean)
    else if($element/@type = "number")
    then xs:string($element)
    else concat('"', json:escape($element), '"')
};

declare function json:outputObject(
    $element as element()
) as xs:string
{
    let $keyValues :=
        for $child in $element/*
        return concat('"', local-name($child), '":', json:processElement($child))
    return concat("{", string-join($keyValues, ","), "}")
};

declare function json:outputArray(
    $element as element()
) as xs:string
{
    let $values :=
        for $child in $element/*
        return json:processElement($child)
    return concat("[", string-join($values, ","), "]")
};

(: Need to backslash escape any double quotes, backslashes, and newlines :)
declare function json:escape(
    $string as xs:string
) as xs:string
{
    let $string := replace($string, "\\", "\\\\")
    let $string := replace($string, """", "\\""")
    let $string := replace($string, codepoints-to-string((13, 10)), "\\n")
    let $string := replace($string, codepoints-to-string(13), "\\n")
    let $string := replace($string, codepoints-to-string(10), "\\n")
    return $string
};
