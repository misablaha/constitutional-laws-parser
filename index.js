process.env.TZ = 'UTC';

const _ = require('lodash');
const fs = require('fs');
const peg = require('pegjs');
const farmhash = require('farmhash');
const BigNumber = require('bignumber.js');

const fragmentsGrammar = fs.readFileSync('gramar/law.fragments.pegjs', 'utf8');
const summaryGrammar = fs.readFileSync('gramar/law.summary.pegjs', 'utf8');

const fragmentsParser = peg.generate(fragmentsGrammar);
const summaryParser = peg.generate(summaryGrammar);

// const file = fs.readFileSync('data/121_2000_Sb.txt', 'utf8');
const file = fs.readFileSync('data/181_2014_Sb.txt', 'utf8');
// let file = fs.readFileSync('data/262_2006_Sb.txt', 'utf8')
// let file = fs.readFileSync('data/89_2012_Sb.txt', 'utf8')
// let file = fs.readFileSync('data/136_2017_Sb.txt', 'utf8')
// let file = fs.readFileSync('data/137_2017_Sb.txt', 'utf8')
// let file = fs.readFileSync('data/138_2017_Sb.txt', 'utf8')

const fragments = fragmentsParser.parse(file);
const summary = summaryParser.parse(file);

const result = Object.assign({
  head: null,
  novels: null,
  fragments: null,
  summary: null,
}, fragments, summary);

/* 1. Create IDs and prepare list of content items */

const path = [];
const contentList = [];

function makeId(item, index) {
  const itemKey = item.type + (item.number || index || '');
  path.push(itemKey);

  const hash = farmhash.hash64(path.join('.'));
  const numberHash = new BigNumber(hash);
  const id = numberHash.toString(62);
  Object.assign(item, { id });
  contentList.push(item);

  if (item.headLine) makeId(item.headLine);
  if (item.title) makeId(item.title);
  if (item.content) walk(item.content);

  path.pop();
}

function walk(content) {
  content.forEach(makeId);
}

path.push(result.head.code);
makeId(result.head.number);
makeId(result.head.type);
makeId(result.head.issuedAt);
makeId(result.head.title);
makeId(result.issuedBy);
walk(result.summary);

/* 2. Complete fragments by contentList */

result.fragments.forEach((fragment) => {
  const matches = _.findLast(contentList, ({ lines }) => lines[0] === fragment.lines[0]);
  if (matches) {
    const { id, type, level } = matches;
    _.merge(fragment, { id, type, level });
    delete fragment.lines;
  }
});

fs.writeFileSync('result.summary.json', JSON.stringify(summary));
fs.writeFileSync('result.fragments.json', JSON.stringify(fragments));
fs.writeFileSync('result.json', JSON.stringify(result));
