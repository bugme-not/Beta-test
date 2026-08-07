from flask import Flask, render_template_string, request, jsonify
import json
import base64
import re
import contextlib
from typing import Optional, Dict, Any, List, Union
from Crypto.Cipher import ChaCha20, AES
from Crypto.Util.Padding import unpad

app = Flask(__name__)
app.secret_key = "offline_hc_decryptor_2026"

VALID_USERS = {
    "Cxlvin777": "Cxlvin777",
    "root": "admin",
    "guest": "1234"
}

HTML_CONTENT = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HTTP Custom Decryptor - Offline</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
        body { background: #121212; color: #e0e0e0; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
        .container { width: 100%; max-width: 700px; }
        .card { background: #1e1e1e; border-radius: 12px; padding: 30px; box-shadow: 0 8px 32px rgba(0,0,0,0.5); transition: all 0.3s ease; }
        .hidden { display: none !important; }
        h1 { color: #4fc3f7; margin-bottom: 25px; text-align: center; font-size: 24px; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 8px; font-weight: 500; color: #b0bec5; }
        input { width: 100%; padding: 12px; border: 1px solid #37474f; border-radius: 8px; background: #263238; color: #fff; font-size: 15px; transition: border 0.3s; }
        input:focus { outline: none; border-color: #4fc3f7; }
        button { width: 100%; padding: 12px; background: #1976d2; color: white; border: none; border-radius: 8px; font-size: 16px; font-weight: 500; cursor: pointer; transition: background 0.3s, transform 0.2s; }
        button:hover { background: #1565c0; transform: translateY(-2px); }
        button:disabled { background: #455a64; cursor: not-allowed; transform: none; }
        .error { color: #ff5252; margin: 10px 0; text-align: center; font-size: 14px; }
        .success { color: #69f0ae; margin: 10px 0; text-align: center; font-size: 14px; }
        .upload-area { border: 2px dashed #4fc3f7; border-radius: 8px; padding: 40px 20px; text-align: center; margin: 20px 0; cursor: pointer; transition: all 0.3s; }
        .upload-area:hover { background: #263238; border-color: #81d4fa; }
        #fileInput { display: none; }
        .file-name { margin-top: 10px; color: #81d4fa; font-weight: 500; }
        .result-box { margin-top: 25px; background: #263238; border-radius: 8px; padding: 20px; max-height: 500px; overflow-y: auto; white-space: pre-wrap; word-break: break-all; font-family: monospace; font-size: 13px; line-height: 1.5; }
        .logout-btn { background: #ef5350; margin-top: 15px; }
        .logout-btn:hover { background: #e53935; }
    </style>
</head>
<body>
    <div class="container">
        <div id="loginPage" class="card">
            <h1>🔐 Login Required</h1>
            <div class="form-group">
                <label>Username</label>
                <input type="text" id="username" autocomplete="off">
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" id="password">
            </div>
            <div id="loginError" class="error hidden"></div>
            <button onclick="handleLogin()">Sign In</button>
        </div>
        <div id="mainPage" class="card hidden">
            <h1>📂 HTTP Custom (.hc) Decryptor</h1>
            <div class="upload-area" onclick="document.getElementById('fileInput').click()">
                <p>Click here or drag & drop your .hc file</p>
                <input type="file" id="fileInput" accept=".hc">
                <div class="file-name" id="selectedFile"></div>
            </div>
            <button id="decryptBtn" onclick="handleDecrypt()" disabled>Decrypt File</button>
            <div id="decryptStatus" class="hidden"></div>
            <div id="resultArea" class="result-box hidden"></div>
            <button class="logout-btn" onclick="logout()">Logout</button>
        </div>
    </div>
    <script>
        let selectedFile = null;
        window.onload = () => {
            if(localStorage.getItem('isLoggedIn') === 'true') showMainPage();
        };
        function showMainPage() {
            document.getElementById('loginPage').classList.add('hidden');
            document.getElementById('mainPage').classList.remove('hidden');
        }
        function showLoginPage() {
            document.getElementById('loginPage').classList.remove('hidden');
            document.getElementById('mainPage').classList.add('hidden');
            localStorage.removeItem('isLoggedIn');
        }
        async function handleLogin() {
            const username = document.getElementById('username').value.trim();
            const password = document.getElementById('password').value.trim();
            const errorEl = document.getElementById('loginError');
            errorEl.classList.add('hidden');
            if(!username || !password) {
                errorEl.textContent = "Fill both fields";
                errorEl.classList.remove('hidden');
                return;
            }
            try {
                const res = await fetch('/api/login', {
                    method: 'POST', headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({username, password})
                });
                const data = await res.json();
                if(data.success) {
                    localStorage.setItem('isLoggedIn', 'true');
                    showMainPage();
                } else {
                    errorEl.textContent = data.message || "Wrong login";
                    errorEl.classList.remove('hidden');
                }
            } catch (e) {
                errorEl.textContent = "Server not running! Start app first";
                errorEl.classList.remove('hidden');
            }
        }
        document.getElementById('fileInput').addEventListener('change', e => {
            selectedFile = e.target.files[0];
            document.getElementById('selectedFile').textContent = selectedFile ? `Selected: ${selectedFile.name}` : '';
            document.getElementById('decryptBtn').disabled = !selectedFile;
        });
        async function handleDecrypt() {
            if(!selectedFile) return;
            const statusEl = document.getElementById('decryptStatus');
            const resultEl = document.getElementById('resultArea');
            const btn = document.getElementById('decryptBtn');
            statusEl.className = 'hidden'; resultEl.classList.add('hidden');
            btn.disabled = true; btn.textContent = 'Processing...';
            const form = new FormData(); form.append('file', selectedFile);
            try {
                const res = await fetch('/api/decrypt', {method: 'POST', body: form});
                const data = await res.json();
                if(data.success) {
                    resultEl.textContent = data.result;
                    resultEl.classList.remove('hidden');
                } else {
                    statusEl.textContent = data.error || "Failed";
                    statusEl.className = 'error';
                }
            } catch {
                statusEl.textContent = "Server error";
                statusEl.className = 'error';
            } finally {
                btn.disabled = false; btn.textContent = 'Decrypt File';
            }
        }
        function logout() {
            showLoginPage();
            document.getElementById('username').value = '';
            document.getElementById('password').value = '';
            selectedFile = null;
            document.getElementById('selectedFile').textContent = '';
            document.getElementById('resultArea').classList.add('hidden');
        }
        document.getElementById('password').addEventListener('keypress', e=> {
            if(e.key === 'Enter') handleLogin();
        });
    </script>
</body>
</html>'''

# --------------------------
# FULL DECRYPTION CODE HERE
# --------------------------
class HCConstants:
    CHACHA_KEYS: List[bytes] = [
        bytes.fromhex("2be4342943c6f91ff58987f41a1aafd179eeb4e053f5cea55b11d6a7db58bd7d"),
        bytes.fromhex("3380aa278b744ba5b529a7f32fa803e48749280dae378345d9b526cf1dbce372"),
        bytes.fromhex("cea9305c95168b162a335b137c61983b8df54e6375da01136547890f14c5fac3"),
        bytes.fromhex("4beeace0e42bae8f29470cf40cf2dfacd5f4e1f751912bf52e803c8c85792193"),
        bytes.fromhex("f8e5f6ebea90558eb32229da24fd0fb7d813091dafe89bb2954fda33b4c60f63"),
        bytes.fromhex("81342f558a6273bac4548d473f54c4ffc7c41747dee81369acab9c787d41ab9c"),
        bytes.fromhex("45635e6fc70486e2fd10d3c2b4780f02d0b4c5f4aa929fc54f86bb8fa4417944"),
        bytes.fromhex("3d632a251c9820f2baf83e15498d27548fc67921cb437f8ce48505989378adea")
    ]
    RST_KEYS: List[bytes] = [
        b"JN1k3YHc2.6_v235", b"JN1k3YHc_2.7_v71", b"JN1k3YHc2.7.ps69",
        b"JN1k3YHc2.7.6950", b"Jn1K3yHc2.8.ps08", b"Jn1K3yHc2.9.ps6c",
        b"Zk:L7>WKaiK*s9>D", b"!<f!&WIlM**R.B0X", b"b4a5opinx2uloec6"
    ]
    JKL_KEY_OLD: bytes = bytes([0xd5,0xd4,0xd3,0xd2,0xd1,0xd0,0xcf,0xce,0xcd,0xcc,0xbd,0xbc,0xbb,0xba,0xb9,0xb8,0xb7,0xb6,0xb5,0xb4])
    JKL_KEY_NEW: bytes = bytes([8,9,10,11,12,13,14,15,17,17,5,4,3,2,1,0,255,254,253,252])
    TOKEN_MAP: Dict[int, str] = {0:"payload",1:"proxy",2:"lockAllConfig",3:"blockedByRoot",4:"expiryTime",5:"noteEnabled",6:"notes",7:"sshField",8:"mobileDataAndLockProvider",9:"unlockUserAndPass",10:"ovpnConfig",11:"ovpnUserAndPass",12:"sni",13:"unlockUserAndPass2",14:"unknown14",15:"blockedByHwid",16:"cloudconfig",17:"psiphon",18:"name",19:"blockArea",20:"connectionMode",21:"blockedByPassword",22:"unknown22",23:"extraSniffer",24:"psiphon2",25:"v2rayEnabled",26:"v2rayConfig",27:"version",28:"slowdnsEnabled",29:"slowdnsServer",30:"slowdnsPublickey",31:"dnsResolver"}
    BRAILLE_ALPHABET: str = "⠁⠃⠉⠙⠑⠋⠛⠓⠊⠚⠅⠇⠍⠝⠕⠏⠟⠗⠎⠞⠥⠧⠺⠭⠽⠵⠼⠁⠼⠃⠼⠉⠼⠙⠼⠑⠼⠋⠼⠛⠼⠓⠼⠊⠼⠚"
    STATIC_NONCE: bytes = b'\xdb'*8
    RST_XOR_KEY: bytes = bytes(range(2,22))

class HCDecryptor:
    @staticmethod
    def _clean_hex(raw:str)->str:
        if not raw: return ""
        c = re.sub(r'[^0-9a-fA-F]','',raw)
        return f"0{c}" if len(c)%2 else c
    @staticmethod
    def _is_hex(s:str)->bool:
        return bool(s and len(s)>=16 and re.fullmatch(r'^[0-9a-fA-F]+$',s))
    @staticmethod
    def _is_mostly_printable(s:str,strict=False)->bool:
        if not s: return False
        if len(s)<4: return True
        cnt = sum(1 for c in s if c.isprintable() or c in '\t\n\r')
        return (cnt/len(s))>(0.9 if strict else 0.8)
    @staticmethod
    def _extract_z3a(data:str,iv:int)->str:
        if not data: return ""
        out = bytearray()
        for m in re.finditer(r'(-?\d+)\.(-?\d+)',data):
            a,b = int(m.group(1))-iv, int(m.group(2))-iv
            with contextlib.suppress(Exception):
                if (d:=1<<b)!=0: out.append((a//d)%256)
        return out.decode('utf-8','ignore')
    @staticmethod
    def _decrypt_braille(txt:str)->str:
        try:
            return bytes((HCConstants.BRAILLE_ALPHABET.index(txt[i])*16 + HCConstants.BRAILLE_ALPHABET.index(txt[i+1]))&255 for i in range(0,len(txt)-1,2)).decode('utf-8')
        except: return txt
    @classmethod
    def _process_credentials(cls,v:str,ssh=False)->str:
        if not v: return v
        if ssh and v[0] in HCConstants.BRAILLE_ALPHABET: v = cls._decrypt_braille(v)
        pat = r'^([\w\.-]+):([\d\-]+)@(.+):(.+)$' if ssh else r'^([^:]+):(.+)$'
        if m:=re.match(pat,v):
            g = m.groups()
            u,p = g[-2:]
            ud = cls._extract_z3a(u, len(re.findall(r'(-?\d+)\.(-?\d+)',u)))
            pd = cls._extract_z3a(p, len(re.findall(r'(-?\d+)\.(-?\d+)',p)))
            return f"{g[0]}:{g[1]}@{ud or u}:{pd or p}" if ssh else f"{ud or u}:{pd or p}"
        return v
    @classmethod
    def _abc_decrypt(cls,inp:str,key:bytes,nonce=HCConstants.STATIC_NONCE)->str:
        if not inp: return ""
        with contextlib.suppress(Exception):
            d = bytes.fromhex(cls._clean_hex(inp))
            if len(d)>16:
                cip = ChaCha20.new(key=key,nonce=nonce)
                cip.seek(64)
                return cip.decrypt(d[:-16]).decode('utf-8','ignore')
        return ""
    @classmethod
    def _rst_decrypt(cls,txt:str)->Optional[str]:
        with contextlib.suppress(Exception):
            b64 = bytes(b ^ HCConstants.RST_XOR_KEY[i%20] for i,b in enumerate(txt.encode()))
            ct = base64.b64decode(b64)
            for k in HCConstants.RST_KEYS:
                with contextlib.suppress(Exception):
                    out = unpad(AES.new(k,AES.MODE_ECB).decrypt(ct), AES.block_size).decode('utf-8','ignore')
                    if "[splitConfig]" in out: return out
        return None
    @classmethod
    def _jkl_decrypt(cls,txt:str,new=False)->str:
        if not txt: return txt
        k = HCConstants.JKL_KEY_NEW if new else HCConstants.JKL_KEY_OLD
        with contextlib.suppress(Exception):
            pad = len(txt)%4
            b = bytearray(base64.b64decode(txt + '='*(4-pad) if pad else txt, validate=True))
            for i,d in enumerate(b):
                kv = k[i%20]
                b[i] = (((d^0xff)&0xca)|(d&0x35)) ^ (((kv^0xff)&0xca)|(kv&0x35))
            return base64.b64decode(b.decode(), validate=True).decode()
        return txt
    @classmethod
    def _decrypt_field(cls,tok:str,dn:bytes)->str:
        if not tok or tok in {"true","false","lifeTime","[splitPsiphon][splitPsiphon]"} or tok.startswith('<'): return tok
        cand = []
        if cls._is_hex(h:=cls._clean_hex(tok)) and len(h)>=32:
            with contextlib.suppress(Exception): cand.append(bytes.fromhex(h))
        if len(tok)>16:
            with contextlib.suppress(Exception): cand.extend([tok.encode('latin1'), tok.encode()])
        cand = list(dict.fromkeys(cand))
        for cb in [c for c in cand if len(c)>16]:
            pt = cb[:-16]
            for k in HCConstants.CHACHA_KEYS:
                with contextlib.suppress(Exception):
                    cip = ChaCha20.new(key=k,nonce=dn); cip.seek(64)
                    d = cip.decrypt(pt).decode('utf-8','ignore')
                    for n in (True,False):
                        if (o:=cls._jkl_decrypt(d,n))!=d and cls._is_mostly_printable(o): return o
                    if cls._is_mostly_printable(d,True) and any(x in d for x in ("HTTP","@",":","{")) or d.isalnum(): return d
        for n in (True,False):
            if (o:=cls._jkl_decrypt(tok,n))!=tok and cls._is_mostly_printable(o): return o
        return tok
    @staticmethod
    def _extract_initial_payload(data:bytes,hk:str)->Optional[str]:
        with contextlib.suppress(Exception):
            kb = bytes.fromhex(hk)
            kl = len(kb)
            try: enc = data.decode('utf-8','ignore').encode('latin1','ignore')
            except: enc = data
            return bytes(b^kb[i%kl] for i,b in enumerate(enc)).decode('utf-8')
        return None
    @classmethod
    def execute(cls,fb:bytes)->Optional[str]:
        if not fb or not (hp:=cls._extract_initial_payload(fb,"e382e4b8adc386f09f9293")): return None
        with contextlib.suppress(Exception):
            if not (outer:=cls._abc_decrypt(hp,HCConstants.CHACHA_KEYS[5])) or not outer.startswith('{'): return None
            jo = json.loads(outer)
            if not isinstance(jo,dict): return None
            cfg = jo.get("cfg",{})
            is_new = isinstance(cfg,dict) and "content" in cfg
            meta, prot = {}, {}
            if is_new:
                for k,n in {'b':'hwid','f':'area'}.items():
                    if v:=str(jo.get(k) or cfg.get(k) or ""): meta[n]=prot[n]=v
                tc, sd = cfg.get('content'), "[splitConfig]"
            else:
                aobj = jo.get('a',{}) if isinstance(jo.get('a'),dict) else {}
                for k,n in {'bb':'hwid','e':'password','fe':'area','ed':'provider'}.items():
                    if v:=(jo.get(k) if k=='e' else aobj.get(k)):
                        if dv:=cls._abc_decrypt(str(v),HCConstants.CHACHA_KEYS[7]): meta[n]=prot[n]=dv
                tc, sd = jo.get('xy') or aobj.get('xy'), jo.get('uv') or aobj.get('uv')
            if not tc or not sd: return None
            th = lambda s:s.encode().hex() if s else ""
            h,p,pr,a = meta.get('hwid'),meta.get('password'),meta.get('provider'),meta.get('area')
            dh = (th(h)*2) if h and not any((p,pr,a)) else (th(p)+th(h)+th(pr)+th(a))
            dn = bytearray(HCConstants.STATIC_NONCE)
            if dh:
                with contextlib.suppress(Exception):
                    for i,b in enumerate(bytes.fromhex(dh)[:8]): dn[i]=b
            xyd = None
            if is_new:
                xyd = cls._rst_decrypt(str(tc))
                if not xyd:
                    for k in HCConstants.CHACHA_KEYS:
                        if (t:=cls._abc_decrypt(str(tc),k)) and sd in t: xyd=t;break
            else:
                xyd = cls._abc_decrypt(str(tc),HCConstants.CHACHA_KEYS[1])
            if not xyd: return None
            cd = {}
            for i,tok in enumerate(xyd.split(str(sd))):
                if i in (22,24): continue
                lbl = HCConstants.TOKEN_MAP.get(i,f"field_{i}")
                fo = tok
                if is_new: fo = cls._decrypt_field(tok,bytes(dn))
                else:
                    if cls._is_hex(tok): fo = cls._abc_decrypt(tok,HCConstants.CHACHA_KEYS[7],bytes(dn))
                    fo = cls._jkl_decrypt(fo,False)
                if i==7: fo = cls._process_credentials(fo,True)
                elif i==11: fo = cls._process_credentials(fo,False)
                if fo:
                    if isinstance(fo,str):
                        fo = fo.replace("88a05e8772eac3e5703e0cd26c6e6f23de72fb09f7ee5a43283d1681f19d","")
                        with contextlib.suppress(Exception):
                            if fo.startswith(("{","[")): fo=json.loads(fo)
                    if not (isinstance(fo,str) and cls._is_hex(fo)): cd[lbl]=fo
            res = {"Protections":prot,"Config":cd}
            return f"HABIBI HTTP CUSTOM SCRIPT\n{'='*30}\n\n{json.dumps(res,indent=4,ensure_ascii=False)}\n\n{'='*30}\ncode : @HABIBI_1ST"
        return None

# ROUTES
@app.route('/')
def idx(): return render_template_string(HTML_CONTENT)

@app.route('/api/login',methods=['POST'])
def login():
    d = request.json
    u = d.get('username','').strip()
    p = d.get('password','').strip()
    if u in VALID_USERS and VALID_USERS[u]==p: return jsonify(success=True)
    return jsonify(success=False,message="Invalid username or password"),401

@app.route('/api/decrypt',methods=['POST'])
def dec():
    if 'file' not in request.files: return jsonify(error="No file"),400
    f = request.files['file']
    if not f.filename.lower().endswith('.hc'): return jsonify(error="Only .hc files allowed"),400
    r = HCDecryptor.execute(f.read())
    if r: return jsonify(success=True,result=r)
    return jsonify(success=False,error="Decryption failed"),500

if __name__ == '__main__':
    app.run(host='127.0.0.1',port=5000,debug=False)
