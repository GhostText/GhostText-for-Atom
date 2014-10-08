http = require 'http'
ws = require 'nodejs-websocket'


class OnMessage
  constructor: (webSocketConnection) ->
    @webSocketConnection = webSocketConnection
    that = @
    @onTextCallBack = (text) ->
      that.onMessage text

    @editor = null
    @webSocketConnection.on 'text', @onTextCallBack
    @remoteChangedText = null
    @editorTitle = null

  onMessage: (text) ->
    request = JSON.parse text
    console.log request

    if @editor is null
      @editorTitle = request.title
      editorPromise = atom.workspace.open @editorTitle
      that = @
      editorPromise.then (editor) ->
        that.editor = editor
        that.editor.setText request.text
        that.editor.onDidChange (change) ->
          changedText = that.editor.getText()
          console.log that.editor.getSelectedScreenRanges()
          if changedText isnt that.remoteChangedText
            change =
              title: that.editorTitle
              text:  changedText
              syntax: 'TODO'
              selections: []
            change = JSON.stringify change
            that.webSocketConnection.sendText change

        that.editor.onDidDestroy () ->
          console.log 'webSocketConnection close'
          that.webSocketConnection.close()
    else
      @editor.setText request.text
      @remoteChangedText = request.text


module.exports =
  httpStatusServer: null

  activate: (state) ->
    console.log "ACTIVATED"

    @httpStatusServer = http.createServer (req, res) ->
      wsServer = ws.createServer (conn) ->
        console.log "New connection"
        new OnMessage conn

        conn.on "close", (code, reason) ->
          console.log "WebSocket connection closed"

      wsServer.on 'listening', () ->
        console.log 'WebSocket server started, senidnhg tpt resopnse to client'
        response =
          ProtocolVersion: 1
          WebSocketPort: wsServer.socket.address().port
        response = JSON.stringify response
        res.writeHead 200, {'Content-Type': 'application/json'}
        res.end response

      wsServer.listen(0)

    @httpStatusServer.listen 4001

  deactivate: ->
    @httpStatusServer.close
