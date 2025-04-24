const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager")
const axios= require('axios')
const config = require('./config.json')

// DOCS: https://docs.aws.amazon.com/cognito/latest/developerguide/token-endpoint.html

// TEMPLATE VARS
const domain_name = config.domain_name
const secret_arn  = config.secret_arn
const login_path  = config.login_path

// Load Params from Core account
const sm = new SecretsManagerClient({region: "eu-central-1"})
const secret = sm.send(new GetSecretValueCommand({ SecretId: secret_arn }))

exports.handler = async (event) => {

    const request = event.Records[0].cf.request
    const code = request.querystring.split('=')[1]
    const params = JSON.parse((await secret).SecretString) // Consists of client_id, client_secret, pool_id and ui_domain

    const url = `https://${params.ui_domain}.auth.eu-central-1.amazoncognito.com/oauth2/token`
    const auth_token = Buffer.from(`${params.client_id}:${params.client_secret}`).toString("base64")

    const payload = {
        "grant_type": "authorization_code",
        "client_id": params.client_id,
        "code": code,
        "redirect_uri": `https://${domain_name + login_path}`,
    }

    const headers = {
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": `Basic ${auth_token}`,
    }

    let access_token, refresh_token, response

    console.log("Fetching tokens from endpoint..")

    await axios.post(url, payload, {headers: headers}).then(res => {
        console.log("Tokens retrieved successfully: " + res.status + " " + res.statusText)
        access_token = res.data.access_token
        refresh_token = res.data.refresh_token

        response = {
            "status": "307",
            "statusDescription": "Temporary Redirect",
            "headers": {
                "location": [
                    {
                        "key": "location",
                        "value": `https://${domain_name}`,
                    },
                ],
                "set-cookie": [
                    {
                        "key": "Set-Cookie",
                        "value": `accessToken=${access_token}`,
                        "attributes": "Path=/; Secure; HttpOnly; SameSite=Lax",
                    },
                    {
                        "key": "Set-Cookie",
                        "value": `refreshToken=${refresh_token}`,
                        "attributes": "Path=/; Secure; HttpOnly; SameSite=Lax",
                    }
                ],
            },
        }

    }, err => {
        console.log("Could not retrieve tokens: " + err.code)

        response = {
            "status": "307",
            "statusDescription": "Temporary Redirect",
            "headers": {
                "location": [
                    {
                        "key": "location",
                        "value": `https://${domain_name}`,
                    },
                ],
                "set-cookie": [
                    {
                        "key": "Set-Cookie",
                        "value": "accessToken=undefined",
                        "attributes": "Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0",
                    },
                    {
                        "key": "Set-Cookie",
                        "value": "refreshToken=undefined",
                        "attributes": "Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0",
                    }
                ]}
        }
    })

    return response
}
