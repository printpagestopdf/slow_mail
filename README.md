# Slow Mail

<div align="center">
<img src="/fastlane/metadata/android/en-US/images/phoneScreenshots/1.png" />
   &nbsp;&nbsp;&nbsp;
<img width="260" src="/fastlane/metadata/android/en-US/images/phoneScreenshots/2.png" />
</div>


<br /><br />  
Slow Mail is an Android email app designed for viewing and sending emails.
You can add any number of email accounts from various providers, provided they support the standard IMAP and SMTP protocols.

Privacy is a core focus of Slow Mail. For this reason, email lists and message content are never stored locally on your device. All data is automatically cleared as soon as you close the app. Besides enhancing data security, this also means that no device storage is consumed by email data.

The trade-off, of course, is that emails can only be accessed while you have an active internet connection. (On-demand loading also generally takes a bit longer than reading from a local cache – hence the name Slow Mail 😆).

Another privacy-focused feature allows you to save your configured email accounts in an (encrypted) file and import them into Slow Mail only when needed.

When loading from a file, you can choose not to save the imported accounts permanently. Instead, they can temporarily override the app’s current configuration for the active session only.

You can import a configuration file while the app is already open, but it’s equally possible to launch Slow Mail directly with a specific configuration file. These files can reside on any storage medium your device can access (local storage, USB drives, network locations, etc.).

This enables a wide variety of flexible workflows. For example, the app can be set up with standard business accounts, but temporarily overridden with private accounts from a configuration file. After restarting the app, your business accounts will be restored. Similarly, multiple users can share a single device, each loading their own personal configuration file…

### More information and help
Find more information and help [here](https://printpagestopdf.github.io/slow_mail/)

## Features

* **No local storage of emails or message lists**
    * **Advantages:** Enhanced privacy and reduced local storage usage
    * **Disadvantages:** Requires an active internet connection and may result in slower load times
* IMAP and SMTP support
* Export and import configurations (accounts, settings, PGP keys) to external files
* Optional encryption for configuration files
* Session-only configuration overlays
* PGP encryption support