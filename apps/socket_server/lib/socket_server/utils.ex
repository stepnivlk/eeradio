defmodule SocketServer.Utils do
  @moduledoc false

  @chunksize 24_576

  def init_response do
    [
      'ICY 200 OK\r\n',
      'icy-notice1: <BR>This stream requires',
      '<a href=\"http://www.winamp.com/\">Winamp</a><BR>\r\n',
      'icy-notice2: Elixir Shoutcast server<BR>\r\n',
      'icy-name: Erradio radio\r\n',
      'icy-genre: hard\r\n',
      'icy-url: http://localhost:3131/stepnivlk\r\n',
      'content-type: audio/mpeg\r\n',
      'icy-pub: 1\r\n',
      'icy-metaint: #{@chunksize}\r\n',
      'icy-br: 96\r\n\r\n'
    ]
  end

  def make_header(%{author: author, song: song}) do
    bin = "StreamTitle='#{author} - #{song}';StreamUrl='http://localhost:3121/stepnivlk';"

    n_blocks = div(byte_size(bin) - 1, 16) + 1
    n_pad = n_blocks * 16 - byte_size(bin)
    extra = :lists.duplicate(n_pad, 0)

    :erlang.list_to_binary([n_blocks, bin, extra])
  end
end
