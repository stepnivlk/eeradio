defmodule Repository.Repo do
  alias Bolt.Sips

  def songs_from_preferences(conn, %{genre: genre}, length \\ 10) do
    conn
    |> Sips.query!("""
    MATCH (song:Song)-[:IN_ALBUM]->(album)-[:IN_GENRE]->(g:Genre {name: '#{genre}'})
    MATCH (author)-[:AUTHORS]->(album)
    RETURN song.name, song.order, album.name, author.name
    ORDER BY album.rating DESC
    LIMIT #{length}
    """)
    |> Enum.map(&with_path/1)
  end

  def mark_song_for_user(conn, %{song: song}, uid) do
    conn
    |> Sips.query("""
    MATCH (song:Song {name: '#{song}'})
    MATCH (user:User {uid: '#{uid}'})
    CREATE (user)-[:HEARD]->(song)
    """)
  end

  defp with_path(%{
         "author.name" => author,
         "album.name" => album,
         "song.name" => song,
         "song.order" => order
       }) do
    album_path = "#{author} - #{album}"
    song_path = "#{order} - #{song}"

    %{
      author: author,
      album: album,
      song: song,
      path: "mp3/#{to_md5(album_path)}/#{to_md5(song_path)}.mp3"
    }
  end

  defp to_md5(string), do: :crypto.hash(:md5, string) |> Base.encode16(case: :lower)
end
