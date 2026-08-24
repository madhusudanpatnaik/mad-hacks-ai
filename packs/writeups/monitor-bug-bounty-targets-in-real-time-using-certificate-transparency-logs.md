---
title: Monitor Bug Bounty Targets in Real Time Using Certificate Transparency Logs
subtitle: Discover New Bug Bounty Subdomains the Moment They Are Issued
tags:
- Bug Bounty
- Technology
- Programming
- Penetration Testing
- Cybersecurity
published: '2025-12-29'
updated: '2026-01-02'
free: false
freedium_url: https://freedium-mirror.cfd/https://infosecwriteups.com/monitor-bug-bounty-targets-in-real-time-using-certificate-transparency-logs-247caa34d0f9
source_url: https://infosecwriteups.com/monitor-bug-bounty-targets-in-real-time-using-certificate-transparency-logs-247caa34d0f9
---

# Monitor Bug Bounty Targets in Real Time Using Certificate Transparency Logs

*Discover New Bug Bounty Subdomains the Moment They Are Issued*

*Published Dec 29, 2025 · Updated Jan 02, 2026 · Free: No*

### Introduction

In bug bounty hunting, timing matters. By the time a new subdomain is picked up by automated scanners, public wordlists, or program scope updates, it has usually already been tested by others. The real advantage comes from discovering assets the moment they are created. That's where **Certificate Transparency monitoring** helps. In this guide, I'll show you how to use **crtmon** to watch CT logs in real time and get alerts as soon as new subdomains are issued, running 24/7 so you don't miss anything even while you sleep.

### Why Monitor Certificate Transparency?

Whenever a CA (Certificate Authority) issues an SSL/TLS certificate for a domain, it must be logged in a public Certificate Transparency log.

#### By monitoring these logs, you can:

- **Discover "Fresh" Assets:** Test subdomains minutes after they are created.
- **Avoid Duplicates:** Find bugs before they are reported by hunters using static datasets.
- **Automate Recon:** Let the tool do the heavy lifting while you focus on manual testing.

#### How the Workflow Works

- Monitor a real-time Certificate Transparency (CT) log feed
- Extract newly issued domain and subdomain names from the feed
- Match the extracted domains against a predefined list of target domains or keywords
- Send a Telegram and Discord notification whenever a match is detected

### 1. Getting Started: Installation and Setup

Setting up crtmon is straightforward. Head over to the project's GitHub README to grab the latest installation commands. Generally, it's a quick copy-paste into your terminal.

Once installed, run the tool for the first time:

```typescript
crtmon
```


```makefile
# crtmon configuration
# monitor your targets real time via certificate transparency logs

# discord webhook url for notifications
webhook: ""

# telegram bot credentials for notifications (optional)
telegram_bot_token: ""
telegram_chat_id: ""

# target wildcard to monitor
targets:
  -
```

On the first run, it will prompt you for a Discord webhook configuration. Simply create a new webhook in your Discord server, and paste the webhook URL into the configuration when prompted and save it.

If you want to check tool available options, you can use the help command to view the usage details.

```bash
╭─[coffinxp@Lostsec]─[~]                                                                  (WSL at )─[ 36%]─[29,05:34]
╰─ crtmon -h

░█▀▀░█▀▄░▀█▀░█▄█░█▀█░█▀█
░█░░░█▀▄░░█░░█░█░█░█░█░█
░▀▀▀░▀░▀░░▀░░▀░▀░▀▀▀░▀░▀

monitor your targets, hunt fresh assets in real time!

 usage:
    cat targets.txt | crtmon -target -
    crtmon -target example.com -config custom.yaml -notify=discord
    crtmon -target targets.txt
    echo "@reboot nohup crtmon -target example.com > /tmp/crtmon.log 2>&1 &" | crontab -

 options:
    -target      target domain to monitor (file path, single domain, or '-' for stdin)
    -config      path to configuration file (default: ~/.config/crtmon/provider.yaml)
    -notify      notification provider: discord, telegram, both
    -version     show version
    -update      update to latest version
    -h, -help    show this help message

 configuration:
    • config file location: ~/.config/crtmon/provider.yaml
    • supports multiple targets and notification providers

 monitor your targets real time via certificate transparency logs
```

### 2. Real-Time Monitoring & Alerts

To start monitoring a specific target, use the target flag followed by the domain:

```typescript
crtmon -target example.com
```


From this point on, crtmon watches Certificate Transparency logs continuously. As soon as a new certificate is issued for any subdomain under example.com, you'll receive an instant alert on Discord.

#### Multi-Platform Notifications

Want alerts on the go? You can set up **Telegram** as well:

1. Paste your Telegram Bot Token and User ID into the config file.
2. Use the notify flag to choose your platform:

- **Discord**: crtmon -target example.com -notify discord
- **Telegram**: crtmon -target example.com -notify telegram
- **Both**: crtmon -target example.com -notify both



#### Monitoring Multiple Targets at Scale

For larger scopes, you don't need to run the tool separately for each domain, just provide a list file using the target flag. The tool will monitor all domains simultaneously.

```typescript
crtmon -target domains.txt
```


If you prefer not to use flags every time, you can pre-load your domains directly into the configuration file


```typescript
crtmon
```


now run the tool by simply typing crtmon, and it will start sending instant alerts directly to your Discord channel.

### 3. Running 24/7: Persistent Background Monitoring

The real power of this setup comes from running it continuously. Instead of keeping a terminal window open on your local machine, the recommended approach is to run crtmon on a **VPS** so it can monitor targets 24/7.

#### **Using nohup for Background Persistence**

To keep the tool running even after you log out or close your terminal, use nohup tool:

```bash
nohup crtmon -target domains.txt
╭─[coffinxp@Lostsec]─[~]                                                 (WSL at )─[ 58%]─[29,06:21]
╰─ nohup crtmon -target domains.txt
nohup: ignoring input and appending output to 'nohup.out'
```

This pushes the process into the background. You can safely close your terminal or logout, go to sleep, and wake up to a Discord and Telegram channel full of new subdomains to test.

#### Managing the Background Process

If you want to stop the tool later, use a process manager such as btop or htop. Locate the running crtmon process and terminate it. Once stopped, alerts will immediately stop as well.



#### Make crtmon Persistent Across System Reboots

To ensure the tool continues running after a system reboot, set up a cron job using following command

```bash
echo "@reboot nohup crtmon -target github.com > /tmp/crtmon.log 2>&1 &" | crontab -
```

**You can also watch this video where I showed the complete practicle of this method:**

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

#### Tool Repository

[**GitHub - coffinxp/crtmon: Monitor your targets and hunt fresh assets in real time.**](https://github.com/coffinxp/crtmon)
*Monitor your targets and hunt fresh assets in real time. - coffinxp/crtmon*

### Conclusion

The difference between an average hunter and a successful one is timing. Real-time CT monitoring gives you that edge. With crtmon running in the background, fresh assets come to you before anyone else even knows they exist. This lets you focus on meaningful testing early, reduce competition, and increase your chances of finding real, unique bugs.

### Disclaimer

> _The content provided in this article is for educational and informational purposes only. Always ensure you have proper authorization before conducting security assessments. Use this information responsibly._
