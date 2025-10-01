// app.js
const express = require('express');
const app = express();

app.disable('x-powered-by');

const port = process.env.PORT || 3000;
const backgroundColor = process.env.APP_COLOR || '#FFFFFF';

app.get('/healthz', (_req, res) => res.status(200).send('ok'));

app.get('/', (_req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
  <html><head><meta charset="utf-8"><title>Hello</title>
    <style>
      html,body{height:100%;margin:0}
      body{
        background:${backgroundColor};
        color:#fff;
        display:flex;justify-content:center;align-items:center;
        font-family:system-ui,Arial,sans-serif;font-size:3rem
      }
    </style>
  </head>
  <body><h1>Hello world</h1></body></html>`);
});

app.listen(port, () => {
  console.log(`App listening on :${port}`);
});
