_ = require 'underscore'
fs = require 'fs-extra'
shortid = require 'shortid'
frontMatter = require 'yaml-front-matter'

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
    when 'code'
      type = 'ryjo/Highlightr'
      code = rawGadget.content
      theme = 'tomorrow-night-eighties'
      config = { code, theme }
    when 'image'
      type = 'versal/image'
      cleanerUrlInfo = rawGadget.content.replace(/\"/g, '')
      urlParts = cleanerUrlInfo.split('(')[1][...-1].split(' ')
      [url, labelParts...] = urlParts
      asset = imageToAssetId url
      config = { asset }

  id = shortid.generate()
  return { id, type, config }

buildMarkdownGadget = (content) ->
  type = 'markdown'
  buildGadget { type, content }

buildCodeGadget = (content) ->
  type = 'code'
  buildGadget { type, content }

buildImageGadget = (content) ->
  type = 'image'
  buildGadget { type, content }

buildMarkdownAndCodeGadgets = (content) ->
  gadgets = []
  peices = []
  inCodeBlock = false
  _.each content.split('\n'), (line) ->
    if line[0...3] == '```'
      if inCodeBlock
        gadgets.push buildCodeGadget peices.join('\n')
      else
        gadgets.push buildMarkdownGadget peices.join('\n')
      inCodeBlock = !inCodeBlock
      peices = []
    else if line[0...2] == '!['
      unless _.isEmpty peices
        gadgets.push buildMarkdownGadget peices.join('\n')
        peices = []
      gadgets.push buildImageGadget line
    else
      peices.push line
  gadgets.push buildMarkdownGadget peices.join('\n')
  peices = []
  return gadgets

buildHeaderGadget = (content) ->
  type = 'header'
  buildGadget { type, content }

lessonTreeToGadgets = (lessonTree) ->
  title = lessonTree.header
  gadgets = []

  if _.isArray lessonTree.content
    _.each lessonTree.content, (section) ->
      if section.header
        gadgets.push buildHeaderGadget section.header
      if section.content
        gadgets.push buildMarkdownAndCodeGadgets section.content

  else if _.isString lessonTree.content
    gadgets.push buildMarkdownAndCodeGadgets lessonTree.content

  id = shortid.generate()
  gadgets = _.flatten gadgets
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
  , ''

  words = line.split ' '
  return _.first(words) == expectedHeader

markdownContainsAnyHeaders = (markdown, depth) ->
  lines = markdown.trim().split '\n'
  _.any lines, _.partial isHeader, _, depth

splitMarkdownAtHeaders = (markdown, depth) ->
  # if there's no headers return the markdown as-is
  return markdown unless markdownContainsAnyHeaders markdown, depth

  lines = markdown.trim().split '\n'
  documents = _.reduce lines, (sections, line, index) ->
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

  # TODO maybe there's a smarter way but for now we sometimes
  # end up with an empty document at the end
  return _.select documents, (doc) -> _.isUndefined doc.peices

markdownToLessonsTree = (courseMarkdown) ->
  # TODO should be some nice recursive way to do this
  lessons = splitMarkdownAtHeaders courseMarkdown, 1

  _.map lessons, (lesson) ->
    if lesson.content
      lesson.content = splitMarkdownAtHeaders lesson.content, 2
    lesson

markdownToCourseTree = (title, courseMarkdown) ->
  lessons = markdownToLessonsTree courseMarkdown
  return { title, lessons }

imageToAssetId = (image) ->
  imageIds = fs.readJsonSync './images.json'
  return imageIds[image]

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
