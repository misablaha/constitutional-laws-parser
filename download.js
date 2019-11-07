const assert = require('assert');
const url = require('url');
const fs = require('fs');
const request = require('request-promise');

const baseUrl = 'http://portal.gov.cz/app/zakony';
const linkRegexp = /download\?\S+ft=txt/g;

function search(number, year) {
  const uri = `zakon?q=${number}/${year}`;
  return request({ baseUrl, uri })
    .then(body => body.match(linkRegexp) || []);
}

function download(uri) {
  return request({ baseUrl, uri });
}

function parseDownloadLink(uri) {
  const { query } = url.parse(uri, true);
  let nr = query.nr || '';
  nr = nr.replace('~', '%');
  nr = decodeURIComponent(nr);
  const nrParsed = nr.match(/(\d{1,4})\/(\d{4})/);
  assert(nrParsed !== null, 'Invalid download link structure');

  return {
    number: nrParsed[1],
    year: nrParsed[2],
  };
}

search(262, 2006)
  .map((uri) => {
    const { number, year } = parseDownloadLink(uri);
    return download(uri)
      .then(fs.writeFileSync.bind(fs, `./data/${number}_${year}_Sb.txt`));
  });
