# Deploy React (Vite) - Xadrez Arena

Passos locais:

1. npm install
2. npm run dev
3. npm run build
4. npm run preview

Arquivos importantes:

- index.html: entrada da aplicacao React
- src/main.jsx: bootstrap React
- src/App.jsx: iframe que carrega o jogo em public/xadrez-arena.html
- public/xadrez-arena.html: jogo original

Deploy em Vercel:

- Framework Preset: Vite
- Build Command: npm run build
- Output Directory: dist

Passo a passo (Dashboard):

1. Suba o projeto para o GitHub.
2. No Vercel, clique em New Project.
3. Importe o repositorio.
4. Confirme as opcoes de build (ja definidas em vercel.json).
5. Clique em Deploy.

Passo a passo (CLI):

1. npx vercel login
2. npx vercel
3. npx vercel --prod

Deploy em Netlify:

- Build command: npm run build
- Publish directory: dist
