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
  currentGadgetMarkdown = []
  markdownLines = _lessonMarkdown.trim().split "\n"
  _.each _.compact(markdownLines), (line) ->
    words = line.split ' '
    if _.first(words) == '##'
      unless _.isEmpty currentGadgetMarkdown
        gadgets.push markdownToGadget currentGadgetMarkdown
      currentGadgetMarkdown = []
      type = 'versal/header'
      content =_.rest(words).join ' '
      config = { content }
      id = shortid.generate()
      gadgets.push { id, type, config }
    else
      currentGadgetMarkdown.push line

  unless _.isEmpty currentGadgetMarkdown
    gadgets.push markdownToGadget currentGadgetMarkdown
  return gadgets

markdownToGadgets = (_markdown) ->
  markdown = _markdown.join "\n"
  return lessonToGadgets markdown

markdownToLessons = (_courseMarkdown) ->
  lessons = []
  currentLessonMarkdown = []
  markdownLines = _courseMarkdown.trim().split "\n"
  _.each _.compact(markdownLines), (line) ->
    words = line.split ' '
    if _.first(words) == '#'
      unless _.isEmpty currentLessonMarkdown
        _.last(lessons).gadgets = markdownToGadgets currentLessonMarkdown
      currentLessonMarkdown = []
      title = _.rest(words).join ' '
      id = shortid.generate()
      lessons.push { id, title }
    else
      currentLessonMarkdown.push line

  unless _.isEmpty currentLessonMarkdown
    _.last(lessons).gadgets = markdownToGadgets currentLessonMarkdown
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
