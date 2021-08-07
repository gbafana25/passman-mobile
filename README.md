# passman (mobile)

Mobile version of passman

## Summary

Encrypted password files are stored locally, and are updated with a remote private repository.  OAuth is used to access the private repo.  Websites can have multiple usernames associated with them.  Currently, the last used password stays in the clipboard in plaintext. 


## TODO
- fix behavior where username buttons have to be clicked twice in order for the password to be copied
- make clipboard erase password after one use (like with xclip, if possible)
- ~save settings in config page to local app storage~
- ~add OAuth app settings to config page (client id, client secret, callback uri)~
- ~copy decrypted passwords to clipboard~
- ~decrypt passwords when buttons are clicked in "saved logins" section~
- ~download raw encrypted password files, organize in same way as desktop (website_name/username)~
