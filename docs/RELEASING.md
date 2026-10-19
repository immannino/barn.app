# Releasing barn

barn is released **from your Mac**: `make publish VERSION=0.2.0` signs, notarizes, tags, creates the GitHub Release (with `barn.dmg`, `barn-<version>.zip` and `checksums.txt`), and optionally updates the Homebrew cask. GitHub Actions only runs CI and deploys the website. A CI release workflow exists but is manual-only. To have CI do releases instead, see [Releasing from CI](#releasing-from-ci-optional).

## Releasing from your Mac

First, create the repo ([step 0](#0-create-the-repo)) and set up the website ([step 5](#5-website-on-barnopecool)). Both apply no matter how you release. Optionally create a [Homebrew tap](#4-homebrew-tap-optional-recommended) repo; you can skip its token when publishing locally.

One-time setup, on the Mac with the Developer ID private key:

```sh
security find-identity -v -p codesigning     # should list "Developer ID Application: …"
xcrun notarytool store-credentials barn-notary \
  --apple-id you@example.com --team-id 4PVT5ZU6L6 --password <app-specific-password>
#   (app-specific password: account.apple.com → Sign-In and Security → App-Specific Passwords)
brew install gh && gh auth login
```

Each release:

```sh
git switch main && git pull
make publish VERSION=0.2.0                              # or: TAP_DIR=../homebrew-tap make publish VERSION=0.2.0
```

`publish.sh` refuses to run with uncommitted changes or a tag that already exists. It writes the files to `build/` before tagging, so a failed notarization never leaves a half-published release.

> ⚠️ Your Developer ID certificate **expires 2027-02-01**. Releases notarized before then keep opening for users. To keep shipping after that date, create a new certificate in Xcode → Settings → Accounts → Manage Certificates → **+** → Developer ID Application. Same team, so users keep their Automation permission.

---

# Releasing from CI (optional)

Everything below is only needed if you want GitHub Actions to sign and notarize instead of your Mac.

## 0. Create the repo

```sh
./scripts/set-owner.sh immannino    # puts your GitHub name into the README, site and cask
git add -A && git commit -m "barn 0.1.0"
gh repo create immannino/barn.app --public --source . --push
```

## 1. Developer ID certificate (`.p12`)

One **Developer ID Application** certificate signs every app you ship, so reuse the one from your other app. You need it together with its **private key**, as a `.p12`. A `.cer` alone isn't enough.

On the Mac that has the key (the one where the certificate was created):

1. Open **Keychain Access** → *login* keychain → **My Certificates**.
2. Find **Developer ID Application: ANTHONY JOSEPH MANNINO (4PVT5ZU6L6)** and expand it. There should be a private key under it.
3. Right-click the certificate → **Export…** → format **.p12** → choose a strong password.

> ⚠️ The certificate you have now **expires 2027-02-01**. Releases notarized before then keep opening for users, but after that date you can't sign new ones. When it's time, create a new one in Xcode → Settings → Accounts → Manage Certificates → **+** → Developer ID Application, export it the same way, and update the two secrets below. You need the Account Holder role, and Apple limits how many Developer ID certificates you can have, so revoke unused ones first.

## 2. Notarization key (App Store Connect API)

This is better for CI than an Apple ID password: it doesn't involve 2FA, it's scoped to one team, and you can revoke it.

1. Go to [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api) → **Team Keys** → **+**.
2. Name it `barn notary` with the access level **Developer**.
3. Download `AuthKey_XXXXXXXXXX.p8`. **Apple only lets you download it once.**
4. Write down the **Key ID** (the XXXXXXXXXX) and the **Issuer ID** (the UUID above the list).

## 3. GitHub secrets

From the repo folder, with the files from steps 1 and 2:

```sh
base64 -i barn-signing.p12 | gh secret set DEVELOPER_ID_P12
gh secret set DEVELOPER_ID_P12_PASSWORD          # prompts; paste the .p12 password
base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set NOTARY_KEY_P8
gh secret set NOTARY_KEY_ID --body XXXXXXXXXX
gh secret set NOTARY_ISSUER_ID --body 00000000-0000-0000-0000-000000000000
```

Then delete the `.p12` and `.p8` from disk, or keep them in a password manager. They're in `.gitignore`, but don't leave them lying around.

| Secret | What |
|---|---|
| `DEVELOPER_ID_P12` | base64 of the exported `.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | its export password |
| `NOTARY_KEY_P8` | base64 of `AuthKey_*.p8` |
| `NOTARY_KEY_ID` | API key ID |
| `NOTARY_ISSUER_ID` | API issuer ID |
| `HOMEBREW_TAP_TOKEN` | *(optional)* see step 4 |

You don't need an identity-name secret: `release.sh` finds the Developer ID identity in the keychain on its own.

## 4. Homebrew tap (optional, recommended)

1. Create a public repo named **`homebrew-tap`** with just a README.
2. Create a [fine-grained token](https://github.com/settings/personal-access-tokens/new) with access to *only* `homebrew-tap` and permission **Contents: read and write**.
3. `gh secret set HOMEBREW_TAP_TOKEN` and paste the token.

Each release then commits `Casks/barn.rb` with the new version and sha256, so `brew install --cask immannino/tap/barn` and `brew upgrade` just work. Without the token, the release still publishes; the tap step is skipped.

## 5. Website on barn.ope.cool

1. Repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. At your DNS provider for `ope.cool`, add **CNAME** `barn` → `immannino.github.io`.
3. Settings → Pages → Custom domain: `barn.ope.cool` (`site/CNAME` already says so). Once the certificate is issued, turn on **Enforce HTTPS**.
4. Recommended: verify `ope.cool` under your **account** Settings → Pages → *Verified domains*, so no other repo can claim the subdomain.

The `pages` workflow publishes `site/` on every push to `main` that touches it.

## 6. Turn on tag releases

In `.github/workflows/release.yml`, uncomment the `push: tags` trigger. Do a dry run first: **Actions → release → Run workflow** with version `0.1.0` builds, signs and notarizes without publishing, and uploads the files as a workflow artifact. Download `barn.dmg` and open it on a Mac. It should open with no Gatekeeper warning, and

```sh
spctl --assess --type execute --verbose /Applications/barn.app   # → accepted, source=Notarized Developer ID
```

Then ship:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

## Troubleshooting

- **Notarization "Invalid"**: run `xcrun notarytool log <submission-id> --key … --key-id … --issuer …` to see the exact problem. It's usually a nested binary that isn't signed with the hardened runtime. `build-app.sh` signs everything with `--options runtime`.
- **`errSecInternalComponent` while signing in CI**: the keychain's partition list wasn't set; check the "Import Developer ID certificate" step's output.
- **No `macos-26` runner**: Liquid Glass needs the macOS 26 SDK. If the image is missing, use the newest `macos-*` image with Xcode 26 installed and keep the "Select Xcode 26" step.
- **Users are asked for Automation permission again after an update**: macOS remembers that permission per signing identity. Keep signing with the same team; switching certificates in the same team is fine.
