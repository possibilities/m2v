_ = require 'underscore'
fs = require 'fs'
shortid = require 'shortid'
frontMatter = require('yaml-front-matter')

markdownToGadget = (markdown) ->
  type = 'versal/markdown'
  data = markdown.join("\n")
  config = { data }
  id = shortid.generate().replace '_', ''
  return { id, type, config }

lessonToGadgets = (_lessonMarkdown) ->
  gadgets = []
  _markdownPeices = []
  markdownLines = _lessonMarkdown.trim().split "\n"

  _.each _.compact(markdownLines), (line) ->
    words = line.split ' '
    if _.first(words) == '##'
      unless _.isEmpty _markdownPeices
        gadget = markdownToGadget _markdownPeices
        gadgets.push gadget
      _markdownPeices = []

      type = 'versal/header'
      content =_.rest(words).join ' '
      config = { content }
      id = shortid.generate()
      gadgets.push { id, type, config }
    else
      _markdownPeices.push line

  unless _.isEmpty _markdownPeices
    gadgets.push markdownToGadget _markdownPeices
  return gadgets

markdownToGadgets = (_markdown) ->
  markdown = _markdown.join "\n"
  return lessonToGadgets markdown

markdownToLessons = (_courseMarkdown) ->
  lessons = []
  _markdownPeices = []
  markdownLines = _courseMarkdown.trim().split "\n"

  _.each _.compact(markdownLines), (line) ->
    words = line.split ' '
    if _.first(words) == '#'
      unless _.isEmpty _markdownPeices
        _.last(lessons).gadgets = markdownToGadgets _markdownPeices
      _markdownPeices = []

      title = _.rest(words).join ' '
      id = shortid.generate()
      lessons.push { id, title }
    else
      _markdownPeices.push line

  unless _.isEmpty _markdownPeices
    _.last(lessons).gadgets = markdownToGadgets _markdownPeices
  return lessons

markdownToCourse = (title, courseMarkdown) ->
  lessons = markdownToLessons courseMarkdown
  return { title, lessons }

markdownToCourseJson = (filePath) ->
  { title, courseMarkdown } = frontMatter.loadFront filePath, 'courseMarkdown'
  courseJson = markdownToCourse title, courseMarkdown
  process.stdout.write JSON.stringify(courseJson), null, 2

filePath = process.argv[2]

usage = 'mv2 </path/to/doc.md>'

unless filePath
  console.info usage
  process.exit 1
unless fs.existsSync filePath
  console.error "Error: '#{filePath}' does not exist"
  console.info usage
  process.exit 1

markdownToCourseJson filePath
