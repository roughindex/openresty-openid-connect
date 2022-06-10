-- runs on every http request that accesses nginx
local function printSession(ngx, opts, session)
  ngx.log(ngx.DEBUG,
    "session.present=", session.present,
    ", session.data.id_token=", session.data.id_token ~= nil,
    ", session.data.authenticated=", session.data.authenticated,
    ", opts.force_reauthorize=", opts.force_reauthorize,
    ", opts.renew_access_token_on_expiry=", opts.renew_access_token_on_expiry,
    ", try_to_renew=", try_to_renew,
    ", token_expired=", token_expired
  )
end

local function endsWith(str, ending)
 return ending == "" or str:sub(-#ending) == ending
end

local function requireAuth(ngx)

  local image = "image"
  local contentType = ngx.var.content_type
  local staticContent = false
  local uri = ngx.var.uri
  local staticEndings = {".js", ".css", ".png", ".gif", ".jpg"}


  if contentType and contentType:sub(1, #image) == image then
    ngx.log(ngx.DEBUG, "Static resource, skipping auth for: " .. uri)
    staticContent = true
  else
    for k,v in pairs(staticEndings) do
      if endsWith(uri, v) then
        staticContent = true
        break
      end
    end
  end
  return not staticContent
end

if requireAuth(ngx) then
  local opts = {
    authorization_params = '$AUTHORIZATION_PARAMS',
    redirect_uri = '$REDIRECT_URI',
    discovery = '$DISCOVERY',
    client_id = '$CLIENT_ID',
    client_secret = '$CLIENT_SECRET',
    ssl_verify = '$SSL_VERIFY',
    logout_path = '$LOGOUT_PATH',
    scope = '$SCOPE',
    session_contents = '$SESSION_CONTENTS'
  }

  local openidc = require("resty.openidc")
  -- Uncomment the line below to see debug logging
  -- openidc.set_logging(nil, { DEBUG = ngx.DEBUG })
  
  local res, err, target, session = openidc.authenticate(opts)

  if err or not session then
    ngx.status = 403
    ngx.log(ngx.WARN, "Error authenticating: " .. err)
    ngx.exit(ngx.HTTP_FORBIDDEN)
  else
    printSession(ngx, opts, session)
    ngx.header["xjwttoken"] = session.data.enc_id_token
    if not string.find(ngx.req.get_headers()["Cookie"], "xjwttoken=") then
      ngx.header["Set-Cookie"] = "xjwttoken=" .. session.data.enc_id_token .. "; SameSite=Strict; Secure;"
    end
    if string.find(ngx.req.get_headers()["Cookie"], "x-jwt-token=") then
      local sessionCookie = ngx.req.get_headers()["Cookie"]
      ngx.req.set_header("x-jwt-token", string.match(sessionCookie, 'x%-jwt%-token=(.-)%;'))
    end
    ngx.header["X-USER"] = session.data.user
  end
end
