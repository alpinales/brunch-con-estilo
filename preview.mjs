// Local development server. Exposes only the files shipped to GitHub Pages.
import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const base=new URL('./',import.meta.url);
const allowed=new Set(['index.html','admin.html','styles.css','app.js','admin.js','quiz-data.js','config.js','assets/mark.svg','assets/perchero-editorial.jpg','assets/cafe-editorial.jpg',...['clasico','romantico','dramatico','natural','creativo','seductor','elegante'].map(s=>`assets/${s}.jpg`)]);
const mime={html:'text/html; charset=utf-8',js:'text/javascript; charset=utf-8',css:'text/css; charset=utf-8',jpg:'image/jpeg',svg:'image/svg+xml'};
http.createServer(async(req,res)=>{try{const path=new URL(req.url,'http://localhost').pathname.slice(1)||'index.html';if(!allowed.has(path)){res.writeHead(404);res.end();return;}const data=await readFile(fileURLToPath(new URL(path,base)));res.writeHead(200,{'Content-Type':mime[path.split('.').pop()],'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(data);}catch{res.writeHead(500);res.end();}}).listen(4173,'127.0.0.1',()=>console.log('Local: http://127.0.0.1:4173'));
