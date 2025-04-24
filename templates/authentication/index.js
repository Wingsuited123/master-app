'use strict'

const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager")
const { CognitoJwtVerifier }                          = require("aws-jwt-verify")
const { JwtExpiredError }                             = require("aws-jwt-verify/error")
const { inRange }                                     = require("range_check")
const config                                          = require('./config.json')

// TEMPLATE VARS -------------------------------------------------------------------------------------------------------

const auth_enabled   = config.auth_enabled
const cognito_groups = config.cognito_groups
const domain_name    = config.domain_name
const ip_whitelist   = config.ip_whitelist
const login_path     = config.login_path
const refresh_path   = config.refresh_path
const secret_arn     = config.secret_arn

// LOAD SM PARAMS ------------------------------------------------------------------------------------------------------

const sm     = new SecretsManagerClient({region: "eu-central-1"})
const secret = auth_enabled ? sm.send(new GetSecretValueCommand({ SecretId: secret_arn })) : null

// HANDLER -------------------------------------------------------------------------------------------------------------

exports.handler = async (event) => {
    const request = event.Records[0].cf.request

    if (auth_enabled) {
        const response = await auth(request)
        if(response) return response
    }

    return request
}

// AUTH ----------------------------------------------------------------------------------------------------------------

async function auth(request) {
    const headers   = request.headers
    const ip        = request.clientIp
    const params    = JSON.parse((await secret).SecretString) // Consists of client_id, client_secret, pool_id and ui_domain

    // Construct redirect URLs

    const login_url   = `https://${params.ui_domain}.auth.eu-central-1.amazoncognito.com/login?response_type=code&client_id=${params.client_id}&redirect_uri=https://${domain_name + login_path}`
    const refresh_url = `https://${domain_name + refresh_path}`

    // Bypass authentication if source IP is whitelisted
    if (inRange(ip, ip_whitelist)) {
        return null
    }

    if (headers.cookie !== undefined) {

        let access_token

        headers.cookie.forEach(cookie => {
            cookie.value.split(';').forEach(sub_cookie => {
                if(sub_cookie.includes("accessToken")){
                    access_token = sub_cookie.split('=')[1]
                    console.log("Access token found..")
                }
            })
        })

        if (access_token) {

            console.log("Checking access token..")

            const verifier = CognitoJwtVerifier.create({
                userPoolId: params.pool_id,
                tokenUse: "access",
                clientId: params.client_id
            })

            try {
                await verifier.verify(access_token, cognito_groups.length > 0 ? { groups: cognito_groups } : {})
                console.log("Token is valid")
                return null
            } catch (err) {
                if (err instanceof JwtExpiredError) {
                    console.log("Access token expired, looking for refresh token..")

                    let refresh_token

                    headers.cookie.forEach(cookie => {
                        cookie.value.split(';').forEach(sub_cookie => {
                            if(sub_cookie.includes("refreshToken")){
                                refresh_token = sub_cookie.split('=')[1]
                                console.log("Refresh token found, ")
                            }
                        })
                    })

                    if(refresh_token) {
                        return send307(refresh_url)
                    }
                }
            }
        }
    }
    return send307(login_url)
}

// HELPER --------------------------------------------------------------------------------------------------------------

const send307 = (url) => {
    console.log(`Redirecting to ${url} ..`)
    return {
        status: '307',
        statusDescription: 'Temporary Redirect',
        headers: {
            location: [{
                key: 'Location',
                value: url
            }]
        }
    }
}

// ---------------------------------------------------------------------------------------------------------------------
