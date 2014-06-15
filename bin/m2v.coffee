_ = require 'underscore'
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
  for line in markdownLines
    if line.trim()
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
  for line in markdownLines
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
markdownToCourseJson filePath
