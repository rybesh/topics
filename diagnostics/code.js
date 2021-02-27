"use strict";

/* global d3 */

const DIAGNOSTICS_FILE = 'data.xml'

const topics = []
const height = 800
const width = 800
const padding = 75

let svg
let topicGroups
let currentXAttr = 'id'
let currentYAttr = 'tokens'

const topicAttributes = [
  'id',
  'tokens',
  'document_entropy',
  'word-length',
  'coherence',
  'uniform_dist',
  'corpus_dist',
  'eff_num_words',
  'token-doc-diff',
  'rank_1_docs',
  'allocation_ratio',
  'allocation_count',
  'exclusivity',
]

const wordAttributes = [
  'rank',
  'count',
  'prob',
  'cumulative',
  'coherence',
  'docs',
  'word-length',
  'uniform_dist',
  'corpus_dist',
  'token-doc-diff',
  'exclusivity',
]

d3.select('#xAttr')
  .selectAll('option')
  .data(topicAttributes)
  .enter()
  .append('option')
  .attr('value', Object)
  .text(a => a.replace(/_/g, ' '))
  .property('selected', a => a === currentXAttr ? 'selected' : '')

d3.select('#yAttr')
  .selectAll('option')
  .data(topicAttributes)
  .enter()
  .append('option')
  .attr('value', Object)
  .text(a => a.replace(/_/g, ' '))
  .property('selected', a => a === currentYAttr ? 'selected' : '')

d3.select('#xAttr')
  .on('change', function () {
    currentXAttr = this.options[this.selectedIndex].getAttribute('value')
    show(currentXAttr, currentYAttr)
  })

d3.select('#yAttr')
  .on('change', function () {
    currentYAttr = this.options[this.selectedIndex].getAttribute('value')
    show(currentXAttr, currentYAttr)
  })


function xmlToObject(element, attrs) {
  const o = {}
  attrs.forEach(a => { o[a] = Number(element.getAttribute(a))})
  return o
}

function show(xAttr, yAttr) {

  const xExtent = d3.extent(topics, topic => topic[xAttr])
  const yExtent = d3.extent(topics, topic => topic[yAttr])

  const xScale = d3.scale.linear()
    .domain(xExtent).range([ padding, width - padding ])
  const yScale = d3.scale.linear()
    .domain(yExtent).range([ height - padding, padding ])

  const xAxis = d3.svg.axis().scale(xScale)
  const yAxis = d3.svg.axis().scale(yScale).orient('left')

  svg.selectAll('.axis').remove()
  svg.append('g')
    .attr('class', 'axis')
    .attr('transform', 'translate(0,' + (height - padding) + ')')
    .call(xAxis)
  svg.append('g')
    .attr('class', 'axis')
    .attr('transform', 'translate(' + padding + ',0)')
    .call(yAxis)

  if (d3.select('.topicGroup').attr('transform')) {
    topicGroups.transition()
      .attr(
        'transform',
        d => 'translate(' + xScale(d[xAttr]) + ',' + yScale(d[yAttr]) + ')'
      )
  }
  else {
    topicGroups
      .attr(
        'transform',
        d => 'translate(' + xScale(d[xAttr]) + ',' + yScale(d[yAttr]) + ')')
  }
}

d3.xml(DIAGNOSTICS_FILE, (error, xml) => {

  const topicTags = xml.documentElement.getElementsByTagName('topic')
  for (let i = 0; i < topicTags.length; i++) {
    const topic = xmlToObject(topicTags[i], topicAttributes)
    const words = topicTags[i].getElementsByTagName('word')
    topic.words = []
    for (let w = 0; w < words.length; w++) {
      const word = xmlToObject(words[w], wordAttributes)
      word.word = words[w].textContent
      topic.words.push(word)
    }
    topics.push(topic)
  }

  svg = d3.select('#plot')
    .append('svg')
    .attr('height', height)
    .attr('width', width)

  const scrollDiv = d3.select('#plot')
    .append('div')
    .attr('class', 'scrolltable')

  const table = scrollDiv.append('table')

  const coherenceScale = d3.scale.linear()
    .domain([ -1, -5 ])
    .range([ '#000000', '#ff0000' ])

  topics.forEach(topic => {
    const row = table.append('tr')
    const textCell = row.append('td')
    textCell.attr('id', 'table_' + topic.id)
      .text((topic.id + 1) + '. ')
      .on('click', () => {
        d3.selectAll('td').style('font-weight', 'normal')
        d3.select('#table_' + topic.id).style('font-weight', 'bold')
        d3.selectAll('circle').style('fill', '#bbbbff')
        d3.select('#circle_' + topic.id).transition().style('fill', '#ff7777')
      })
    topic.words.forEach(word => {
      textCell.append('span')
        .style('color', coherenceScale(word.coherence))
        .text(word.word + ' ')
    })
  })

  topicGroups = svg.selectAll('.topicGroup').data(topics)
  topicGroups.enter().append('g').attr('class', 'topicGroup')
  topicGroups.append('circle')
    .attr('id', topic => 'circle_' + topic.id)
    .attr('r', 8)
    .style('fill', '#bbbbff')
    .style('opacity', 0.7)
    .on('click', topic => {
      d3.selectAll('td').style('font-weight', 'normal')
      d3.select('#table_' + topic.id).style('font-weight', 'bold')
      d3.selectAll('circle').style('fill', '#bbbbff')
      d3.select('#circle_' + topic.id).transition().style('fill', '#ff7777')

      const newScrollTop = (
        -150 +
        (topic.id / topics.length) *
        d3.select('.scrolltable').property('scrollHeight')
      )

      d3.select('.scrolltable')
        .transition()
        .tween('zoomToTopic', function () {
           const interp = d3.interpolateNumber(this.scrollTop, newScrollTop)
           return function (t) { this.scrollTop = interp(t) }
        })
    })

  topicGroups.append('text')
    .attr('dx', 10)
    .attr('dy', '.35em')
    .text(topic => topic.id + 1)
    .style('font-size', 'x-small')
    .style('pointer-events', 'none')

  show('id', 'tokens')
})
