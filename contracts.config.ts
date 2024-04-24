// Fee for protecting (Wei)
export const fees = [0n, 0n, 0n]
// Account who can update MetaEvidences
export const metaEvidenceLoader = '0xD05B13E2C5E0e1071442F9F7C99beE136ecced43'
// Arbitrators config
export const arbitrators = {
    "goerli": {
        "name": "Kleros",
        "address": "0x99489d7bb33539f3d1a401741e56e8f02b9ae0cf",
        "extraData": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003"
    },
    "sepolia": {
        "name": "Kleros",
        "address": "0x1780601e6465f32233643f3af54abc3d8df161be",
        "extraData": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003"
    }
}
// App metadata endpoints
export const metadataURIs = {
    "goerli": "https://dev.nftprotect.app/api/metadata/5/",
    "sepolia": "https://dev.nftprotect.app/api/metadata/11155111/"
}
// List of MetaEvidences to be registered
export const metaEvidences = [
    {
        "id": 3,
        "name": "OwnershipAdjustment",
        "url": "/ipfs/QmQenFQfQgXQHV9Whf3FG1JJ6tJu5fyL7mQyDPnjtveenz/metaEvidence.json"
    }, {
        "id": 4,
        "name": "AskOwnershipRestoreArbitrate-Mistake",
        "url": "/ipfs/QmYKeA1xREyEGxjcdHo3tdii6hXaYJtP9LKdvff114oKay/metaEvidence.json"
    }, {
        "id": 5,
        "name": "AskOwnershipRestoreArbitrate-Phishing",
        "url": "/ipfs/QmXFXrprk5b1eN3iVvCQ57TUcr1DUWVBzUooS8jVFJomi5/metaEvidence.json"
    }, {
        "id": 6,
        "name": "AskOwnershipRestoreArbitrate-ProtocolBreach",
        "url": "/ipfs/QmTF9mXDaabUZHiNfDiNSdA45TQCFxh9A45cPhTwY1e4fN/metaEvidence.json"
    }
]