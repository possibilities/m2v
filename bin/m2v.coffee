_ = require 'underscore'
fs = require 'fs'
shortid = require 'shortid'
frontMatter = require('yaml-front-matter')

buildGadget = (rawGadget) ->
  type = config = null
  switch rawGadget.type
    when 'header'
      type = 'versal/header'
      content = rawGadget.content
      config = { content }
    when 'markdown'
      type = 'versal/markdown'
      data = rawGadget.content
      config = { data }
  id = shortid.generate()
  return { id, type, config }

lessonTreeToGadgets = (lessonTree) ->
  title = lessonTree.header
  gadgets = []

  if _.isArray lessonTree.content
    _.each lessonTree.content, (section) ->
      if section.header
        type = 'header'
        content = section.header
        gadgets.push buildGadget { type, content }

      if section.content
        type = 'markdown'
        content = section.content
        gadgets.push buildGadget { type, content }

  else if _.isString lessonTree.content
    type = 'markdown'
    content = lessonTree.content
    gadgets.push buildGadget { type, content }

  id = shortid.generate()
  return { id, title, gadgets }

courseTreeToCourseJson = (title, courseTree) ->
  lessons = _.reduce courseTree, (lessons, _lesson) ->
    lesson = lessonTreeToGadgets _lesson
    if lesson.gadgets.length
      lessons.push lesson
    return lessons
  , []
  return { title, lessons }

isHeader = (line, depth) ->
  expectedHeader = _.reduce _.range(depth), (str) ->
    str += '#'
  , ""

  words = line.split ' '
  return _.first(words) == expectedHeader

markdownContainsAnyHeaders = (markdown, depth) ->
  lines = markdown.trim().split '\n'
  _.any lines, _.partial isHeader, _, depth

splitMarkdownAtHeader = (markdown, depth) ->
  # if there's no headers return the markdown as-is
  return markdown unless markdownContainsAnyHeaders markdown, depth

  lines = markdown.trim().split '\n'
  return _.reduce lines, (sections, line, index) ->
    section = _.last sections
    if isHeader line, depth
      section.header = _.rest(line.split(' ')).join ' '
    else
      section.peices.push line
      nextLine = lines[index + 1]
      if index >= (lines.length - 1) || nextLine && isHeader nextLine, depth
        section.content = section.peices.join '\n'
        delete section.peices
        sections.push { peices: [] }

    return sections
  , [{ peices: [] }]

markdownToLessonsTree = (courseMarkdown) ->
  # TODO should be some nice recursive way to do this
  lessons = splitMarkdownAtHeader courseMarkdown, 1
  _.map lessons, (lesson) ->
    if lesson.content
      lesson.content = splitMarkdownAtHeader lesson.content, 2
    lesson

markdownToCourseTree = (title, courseMarkdown) ->
  lessons = markdownToLessonsTree courseMarkdown
  return { title, lessons }

markdownToCourseJson = (title, courseMarkdown) ->
  courseTree = markdownToLessonsTree courseMarkdown
  courseJson = courseTreeToCourseJson title, courseTree
  process.stdout.write JSON.stringify(courseJson, null, 2)

filePath = process.argv[2]

usage = 'mv2 </path/to/doc.md>'

unless filePath
  console.info usage
  process.exit 1
unless fs.existsSync filePath
  console.error "Error: '#{filePath}' does not exist"
  console.info usage
  process.exit 1

{ title, courseMarkdown } = frontMatter.loadFront filePath, 'courseMarkdown'
markdownToCourseJson title, courseMarkdown
