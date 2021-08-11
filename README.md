# passman (mobile)

Mobile version of passman

## Summary

Encrypted password files are stored locally, and are updated with a remote private repository.  OAuth is used to access the private repo.  Websites can have multiple usernames associated with them.  Currently, the last used password stays in the clipboard in plaintext.

## Setup

- Make sure you have a private repository setup with all your encrypted password files and folders
- Setup a ![OAuth app](https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app)
- Open the app and go to the `Config` page.  Input your github username, repository, gpg password, client ID, and client secret 
- Click `Login` if it's your first time using the app
- Go to the `Account` page and click `refresh repo`
- A list of sites will appear under `Saved Logins` (you may need to refresh the page in order for them to appear)


## TODO
- add feature to add credentials from the mobile app
- make clipboard erase password after one use (like with xclip, if possible)
