# brain/lesson-index — class → lesson-selection keywords

`brain.sh recall-class <class>` reads this file, extracts the keyword set for `<class>`, greps `brain/lessons.md`, and prints matching lessons. Every hunter briefing should call `brain.sh recall-class <its-class>` at dispatch so class-relevant heuristics auto-fire — no operator memory required.

**Extending:** add new classes by appending a row `class|kw1,kw2,kw3` — one entry per line, no header. `brain.sh recall-class` parses this literal format. Keep keywords lowercase.

## Class → keyword-set (parsed literally by brain.sh)

<!-- BEGIN INDEX -->
ssrf|ssrf,oob,collaborator,interactsh,oastify,webhook,blind ssrf,imdsv2,imdsv1,169.254,metadata
xss|xss,reflection,stored xss,dom xss,pastejack,blind-xss,domain,waf,csp,dompurify,mxss,dalfox
sqli|sqli,sql injection,sqlmap,ghauri,time-based,error-based,nosql,union-based,boolean-blind
idor|idor,bola,object-level,org_id,ownership,multi-tenant,tenant boundary,horizontal,vertical
auth-session|session,jwt,oauth,saml,mfa,auth bypass,login,bearer,lambda authorizer,alg-none,kid
rce|rce,command injection,deserial,ssti,react2shell,eval,exec,os command
lfi|lfi,path traversal,file inclusion,directory traversal,../,etc/passwd
crlf|crlf,%0d,%0a,header injection,response splitting
cache-poison|cache poisoning,unkeyed header,cache key
cache-deception|cache deception,static extension,path poison,delimiter,%2f,url suffix
xxe|xxe,xml entity,xml external,billion laughs,dtd
cors|cors,origin reflection,access-control-allow,null origin
csrf|csrf,samesite,cross-site request,state-changing
ratelimit|rate limit,429,brute-force,brute force,otp brute,captcha bypass
recon|recon,subfinder,nuclei,katana,httpx,wayback,crt.sh,shodan,asn,dnsx,gau
burp|burp,repeater,intruder,toolsearch,mcp,collaborator
workflow|workflow,orchestrat,brain,lesson,router,dispatch,memory,ruflo,cdc harness
safety|production-safety,authorization,scope,destructive,r1,r11,rules of engagement
reporting|report,evidence,artifact,verdict,triager,cvss,cwe,severity,redact
race|race,toctou,parallel request,concurrent,check-then-act
business-logic|business logic,workflow bypass,coupon,price manipulation,tier bypass,plan bypass
mass-assignment|mass assign,mass-assignment,admin flag,role field,isadmin,__proto__
wordpress|wordpress,wpscan,wp-,xmlrpc,admin-ajax
graphql|graphql,introspection,batching,alias overloading
registration|registration,signup,sign-up,email verification,duplicate account
punycode|punycode,idn,homograph,unicode identifier
file-upload|file upload,polyglot upload,svg upload,upload-then-execute,extension filter
open-redirect|open redirect,returnurl,redirect_uri,returnto,url= param
subdomain-takeover|subdomain takeover,cname,dangling,nosuchbucket,heroku claim
info-disclosure|info disclosure,stack trace,debug endpoint,.env,.git,error verbose
oauth|oauth,openid,oidc,pkce,state,nonce,jku,kid,alg confusion
saml|saml,xsw,assertion replay,comment injection
mfa|mfa,2fa,totp,otp,backup code
llm-ai|llm,prompt injection,tool abuse,rag,vector,mcp attack,agentic
websocket|websocket,ws://,wss://,upgrade,subprotocol
cloud|cloud,s3,gcs,azure blob,iam,metadata,imds,cognito
tls|tls,ssl,cert,heartbleed,openssl
dalfox|dalfox,--blind-oob,--custom-payload,--dry-run,scan_with_dalfox,preflight_dalfox,rmcp
active-directory|active directory,ad-breach,kerberos,kerberoast,as-rep,dcsync,laps,gpp,adcs,esc1,esc8,bloodhound,ntlm relay,petitpotam,printerbug
android|android,apk,apktool,jadx,masvs,droid,manifest,cleartext,mobsf
clickjacking|clickjacking,ui redressing,frame busting,x-frame-options,frame-ancestors
hpp|http parameter pollution,hpp,parameter pollution,parameter splitting,duplicate parameter
deadangle|deadangle,verified,inferred,assumed,accuracy check,honesty gate
handoff|handoff,session save,engagement handoff,pick up next session,save progress
<!-- END INDEX -->

## Wiring

- Every specialist hunter's briefing (via `/mad-hunt` or `/cdc-research`) should invoke:
  ```bash
  bash scripts/brain.sh recall-class <class>
  ```
  and paste the returned lessons into its own reasoning before probing.

- `t3-exploiter` auto-invokes this on the candidate's class tag (see its updated §"Brain recall" step).

- Adding a new class: append a row to the `<!-- BEGIN INDEX -->` block and (if useful) add a new payload file at `brain/payloads/<class>.txt`. No script change needed.

## Not-in-index behavior

If `<class>` isn't in the index, `brain.sh recall-class` falls back to a raw grep of the class name against `lessons.md` and prints a warning. Prefer to add the class to the index over relying on the fallback.
