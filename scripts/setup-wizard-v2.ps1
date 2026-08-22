param([int]$Port=8765)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Utf8NoBom=New-Object System.Text.UTF8Encoding($false)
$ProjectRoot=Split-Path -Parent $PSScriptRoot
$UiFile=Join-Path (Join-Path $ProjectRoot 'setup') 'app.html'
$Bootstrap=Join-Path $PSScriptRoot 'bootstrap.ps1'
$script:OwnerDraft=$null
Set-Location $ProjectRoot

function Read-Utf8([string]$Path){ return [IO.File]::ReadAllText((Resolve-Path $Path),[Text.Encoding]::UTF8) }
function Write-Utf8([string]$Path,[string]$Text){ [IO.File]::WriteAllText($Path,$Text,$Utf8NoBom) }
function New-Secret([int]$Length=64){$v='';while($v.Length-lt$Length){$v+=[guid]::NewGuid().ToString('N')};$v.Substring(0,$Length)}
function Ensure-EnvFile{
 if(-not(Test-Path '.env')){[IO.File]::Copy((Resolve-Path '.env.example'),(Join-Path $ProjectRoot '.env'))}
 $raw=Read-Utf8 '.env';$map=@{'CHANGE_ME_STRONG_DATABASE_PASSWORD'=(New-Secret 64);'CHANGE_ME_64_CHARS_OR_MORE'=(New-Secret 64);'CHANGE_ME_32_CHARS_OR_MORE'=(New-Secret 64);'CHANGE_ME_STRONG_PASSWORD'=(New-Secret 40)}
 foreach($k in $map.Keys){if($raw.Contains($k)){$raw=$raw.Replace($k,$map[$k])}}
 Write-Utf8 (Join-Path $ProjectRoot '.env') $raw
}
function Get-EnvMap{$m=@{};if(-not(Test-Path '.env')){return $m};foreach($line in [IO.File]::ReadAllLines((Resolve-Path '.env'),[Text.Encoding]::UTF8)){$t=$line.Trim();if(-not$t-or$t.StartsWith('#')-or-not$t.Contains('=')){continue};$p=$t.Split('=',2);$m[$p[0].Trim()]=$p[1].Trim()};$m}
function Set-EnvValue([string]$Key,[string]$Value){Ensure-EnvFile;$lines=[Collections.Generic.List[string]]::new();$lines.AddRange([IO.File]::ReadAllLines((Resolve-Path '.env'),[Text.Encoding]::UTF8));$found=$false;for($i=0;$i-lt$lines.Count;$i++){if($lines[$i]-match('^'+[regex]::Escape($Key)+'=')){$lines[$i]="$Key=$Value";$found=$true;break}};if(-not$found){$lines.Add("$Key=$Value")};[IO.File]::WriteAllLines((Resolve-Path '.env'),$lines,$Utf8NoBom)}
function Test-Url([string]$Url){try{$r=Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 3;return($r.StatusCode-ge200-and$r.StatusCode-lt400)}catch{return$false}}
function Test-Docker{if(-not(Get-Command docker -ErrorAction SilentlyContinue)){return$false};& docker info *> $null;return($LASTEXITCODE-eq0)}
function Test-Postgres{if(-not(Test-Docker)){return$false};& docker compose exec -T postgres pg_isready *> $null;return($LASTEXITCODE-eq0)}
function Test-Workflow{if(-not(Test-Url 'http://127.0.0.1:5678/healthz')){return$false};$x=(& docker compose exec -T n8n n8n list:workflow 2>&1|Out-String);return($LASTEXITCODE-eq0-and$x-like'*Sistema Agêntico n8n WhatsApp+Email*')}
function Test-N8nNeedsOwner{try{$s=Invoke-RestMethod -Uri 'http://localhost:5678/rest/settings' -TimeoutSec 3;return[bool]$s.data.userManagement.showSetupOnFirstLoad}catch{return$false}}
function Setup-N8nOwnerIfNeeded{if(-not(Test-N8nNeedsOwner)){return};if($null-eq$script:OwnerDraft){throw'Informe nome, sobrenome, e-mail e senha do n8n.'};$payload=$script:OwnerDraft|ConvertTo-Json -Compress;Invoke-RestMethod -Uri 'http://localhost:5678/rest/owner/setup' -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 20|Out-Null;Start-Sleep 1;if(Test-N8nNeedsOwner){throw'O n8n não confirmou a criação do proprietário local.'}}
function Status{$e=Get-EnvMap;[ordered]@{docker=(Test-Docker);postgres=(Test-Postgres);ollama=(Test-Url 'http://127.0.0.1:11434/api/tags');n8n=(Test-Url 'http://127.0.0.1:5678/healthz');waha=(Test-Url 'http://127.0.0.1:3000/health');workflow=(Test-Workflow);setupComplete=(Test-Path '.setup-complete');googleConfigured=[bool]($e['GOOGLE_CLIENT_ID']-and$e['GOOGLE_CLIENT_SECRET']);wahaUser=if($e['WAHA_DASHBOARD_USERNAME']){$e['WAHA_DASHBOARD_USERNAME']}else{'admin'};wahaPassword=if($e['WAHA_DASHBOARD_PASSWORD']){$e['WAHA_DASHBOARD_PASSWORD']}else{''}}}
function Read-Body($Req){if(-not$Req.HasEntityBody){return''};$reader=New-Object IO.StreamReader($Req.InputStream,[Text.Encoding]::UTF8,$true);try{$reader.ReadToEnd()}finally{$reader.Dispose()}}
function Send($Res,[int]$Code,[string]$Type,[string]$Body){$bytes=[Text.Encoding]::UTF8.GetBytes($Body);$Res.StatusCode=$Code;$Res.ContentType=$Type;$Res.ContentEncoding=[Text.Encoding]::UTF8;$Res.Headers['Cache-Control']='no-store, no-cache, must-revalidate';$Res.Headers['Pragma']='no-cache';$Res.Headers['X-Content-Type-Options']='nosniff';$Res.Headers['Content-Security-Policy']="default-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'";$Res.ContentLength64=$bytes.Length;$Res.OutputStream.Write($bytes,0,$bytes.Length);$Res.OutputStream.Close()}
function Json($Res,[int]$Code,$Obj){Send $Res $Code 'application/json; charset=utf-8' ($Obj|ConvertTo-Json -Depth 8 -Compress)}
function Bootstrap([string]$Mode){$o=(& powershell -NoProfile -ExecutionPolicy Bypass -File $Bootstrap -Mode $Mode -NoOpen -NonInteractive 2>&1|Out-String);[ordered]@{code=$LASTEXITCODE;log=$o}}
function Valid-Model([string]$v){$v-match'^[A-Za-z0-9._:/-]{1,80}$'}
function Valid-Pass([string]$v){$v.Length-ge8-and$v.Length-le64-and$v-match'[A-Z]'-and$v-match'\d'}

if(-not(Test-Path $UiFile)){Write-Host '[ERRO] setup/app.html não foi encontrado.' -ForegroundColor Red;exit 1}
Ensure-EnvFile
$prefix="http://127.0.0.1:$Port/";$listener=New-Object Net.HttpListener;$listener.Prefixes.Add($prefix)
try{$listener.Start()}catch{Write-Host "[ERRO] Não foi possível abrir $prefix" -ForegroundColor Red;Write-Host $_.Exception.Message;exit 1}
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host ' Assistente Visual - Sistema Agêntico' -ForegroundColor White
Write-Host " $prefix" -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host 'A interface usa UTF-8 explícito e pode permanecer aberta no navegador.'
Start-Process $prefix
$script:Running=$true
try{
 while($script:Running-and$listener.IsListening){$ctx=$listener.GetContext();$req=$ctx.Request;$res=$ctx.Response;$path=$req.Url.AbsolutePath.ToLowerInvariant();try{
  if($req.HttpMethod-eq'GET'-and($path-eq'/'-or$path-eq'/index.html')){Send $res 200 'text/html; charset=utf-8' (Read-Utf8 $UiFile);continue}
  if($req.HttpMethod-eq'GET'-and$path-eq'/api/status'){Json $res 200 (Status);continue}
  if($req.HttpMethod-eq'GET'-and$path-eq'/api/config'){$e=Get-EnvMap;Json $res 200 ([ordered]@{approvalEmail=$e['APPROVAL_EMAIL'];model=if($e['OLLAMA_MODEL']){$e['OLLAMA_MODEL']}else{'qwen3:4b'};validatorModel=if($e['OLLAMA_VALIDATOR_MODEL']){$e['OLLAMA_VALIDATOR_MODEL']}else{'qwen3:4b'};timezone=if($e['GENERIC_TIMEZONE']){$e['GENERIC_TIMEZONE']}else{'America/Sao_Paulo'};googleClientId=$e['GOOGLE_CLIENT_ID'];googleClientSecret=$e['GOOGLE_CLIENT_SECRET'];googleCallback='http://localhost:5678/rest/oauth2-credential/callback';wahaUser=if($e['WAHA_DASHBOARD_USERNAME']){$e['WAHA_DASHBOARD_USERNAME']}else{'admin'};wahaPassword=$e['WAHA_DASHBOARD_PASSWORD']});continue}
  if($req.HttpMethod-eq'POST'-and$path-eq'/api/config'){$d=(Read-Body $req)|ConvertFrom-Json;$email=[string]$d.approvalEmail;$model=[string]$d.model;$validator=[string]$d.validatorModel;$tz=[string]$d.timezone;$gid=[string]$d.googleClientId;$gsec=[string]$d.googleClientSecret;$fn=[string]$d.ownerFirstName;$ln=[string]$d.ownerLastName;$oe=[string]$d.ownerEmail;$op=[string]$d.ownerPassword;if($email-and$email-notmatch'^[^\s@]+@[^\s@]+\.[^\s@]+$'){throw'E-mail de aprovação inválido.'};if(-not(Valid-Model $model)-or-not(Valid-Model $validator)){throw'Modelo Ollama inválido.'};if(($gid-and-not$gsec)-or($gsec-and-not$gid)){throw'Informe Google Client ID e Client Secret juntos.'};if(-not$fn-or-not$ln){throw'Informe nome e sobrenome.'};if($oe-notmatch'^[^\s@]+@[^\s@]+\.[^\s@]+$'){throw'E-mail de login n8n inválido.'};if(-not(Valid-Pass $op)){throw'A senha n8n deve ter 8 a 64 caracteres, ao menos uma maiúscula e um número.'};$script:OwnerDraft=[ordered]@{email=$oe;firstName=$fn;lastName=$ln;password=$op};Set-EnvValue 'APPROVAL_EMAIL' $email;Set-EnvValue 'OLLAMA_MODEL' $model;Set-EnvValue 'OLLAMA_VALIDATOR_MODEL' $validator;Set-EnvValue 'GENERIC_TIMEZONE' $tz;Set-EnvValue 'GOOGLE_CLIENT_ID' $gid;Set-EnvValue 'GOOGLE_CLIENT_SECRET' $gsec;Json $res 200 ([ordered]@{ok=$true});continue}
  if($req.HttpMethod-eq'POST'-and$path-eq'/api/install'){$p=Bootstrap 'Prepare';if($p.code-ne0){Json $res 500 ([ordered]@{error='A preparação automática falhou.';log=$p.log});continue};Setup-N8nOwnerIfNeeded;$f=Bootstrap 'Finalize';if($f.code-ne0){Json $res 500 ([ordered]@{error='A finalização automática falhou.';log=($p.log+"`n"+$f.log)});continue};Json $res 200 ([ordered]@{ok=$true;log=($p.log+"`n"+$f.log);status=(Status)});continue}
  if($req.HttpMethod-eq'POST'-and$path-eq'/api/start'){$r=Bootstrap 'Start';if($r.code-ne0){Json $res 500 ([ordered]@{error='Falha ao iniciar o sistema.';log=$r.log})}else{Json $res 200 ([ordered]@{ok=$true;log=$r.log;status=(Status)})};continue}
  if($req.HttpMethod-eq'POST'-and$path-eq'/api/shutdown'){Json $res 200 ([ordered]@{ok=$true});$script:OwnerDraft=$null;$script:Running=$false;continue}
  Json $res 404 ([ordered]@{error='Rota não encontrada.'})
 }catch{if($res.OutputStream.CanWrite){Json $res 500 ([ordered]@{error=$_.Exception.Message})}}
 }
}finally{$script:OwnerDraft=$null;if($listener.IsListening){$listener.Stop()};$listener.Close()}
exit 0
