# Releasing barn

Push a `v*` tag and GitHub Actions does the rest:

1. Builds a universal app and runs the tests.
2. Signs with your Developer ID and notarizes it with Apple.
3. Publishes a GitHub Release with `barn.dmg` (for people), `barn-<version>.zip` (for Homebrew) and `checksums.txt`.
4. Optionally, updates the Homebrew cask in your tap.

The website deploys separately whenever `site/` changes on `main`.

This is the one-time setup.

## 0. Create the repo

```sh
./scripts/set-owner.sh <your-github-name>    # puts your GitHub name into the README, site and cask
git add -A && git commit -m "barn 0.1.0"
gh repo create <your-github-name>/barn --public --source . --push
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

Each release then commits `Casks/barn.rb` with the new version and sha256, so `brew install --cask <you>/tap/barn` and `brew upgrade` just work. Without the token, the release still publishes; the tap step is skipped.

## 5. Website on barn.ope.cool

1. Repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. At your DNS provider for `ope.cool`, add **CNAME** `barn` → `<your-github-name>.github.io`.
3. Settings → Pages → Custom domain: `barn.ope.cool` (`site/CNAME` already says so). Once the certificate is issued, turn on **Enforce HTTPS**.
4. Recommended: verify `ope.cool` under your **account** Settings → Pages → *Verified domains*, so no other repo can claim the subdomain.

The `pages` workflow publishes `site/` on every push to `main` that touches it.

## 6. First release

Do a dry run first. **Actions → release → Run workflow** with version `0.1.0` builds, signs and notarizes without publishing, and uploads the files as a workflow artifact. Download `barn.dmg` and open it on a Mac. It should open with no Gatekeeper warning, and

```sh
spctl --assess --type execute --verbose /Applications/barn.app   # → accepted, source=Notarized Developer ID
```

Then ship:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

## Releasing from your own Mac

Once the Developer ID identity is in your keychain:

```sh
# one time: store notary credentials (API key, or Apple ID + app-specific password)
xcrun notarytool store-credentials barn-notary --key AuthKey_XXXX.p8 --key-id XXXX --issuer <issuer-uuid>

./scripts/release.sh 0.1.0      # → build/barn.dmg, build/barn-0.1.0.zip, build/checksums.txt
```

## Troubleshooting

- **Notarization "Invalid"**: run `xcrun notarytool log <submission-id> --key … --key-id … --issuer …` to see the exact problem. It's usually a nested binary that isn't signed with the hardened runtime. `build-app.sh` signs everything with `--options runtime`.
- **`errSecInternalComponent` while signing in CI**: the keychain's partition list wasn't set; check the "Import Developer ID certificate" step's output.
- **No `macos-26` runner**: Liquid Glass needs the macOS 26 SDK. If the image is missing, use the newest `macos-*` image with Xcode 26 installed and keep the "Select Xcode 26" step.
- **Users are asked for Automation permission again after an update**: macOS remembers that permission per signing identity. Keep signing with the same team; switching certificates in the same team is fine.
