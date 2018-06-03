defmodule Repository.Repo do
  alias Bolt.Sips

  def songs_from_preferences(conn, %{genre: genre, user_uid: user_uid}, length \\ 10) do
    conn
    |> Sips.query!("""
    MATCH (song:Song)-[:IN_ALBUM]->(album)-[:IN_GENRE]->(g:Genre {name: '#{genre}'})
    MATCH (author)-[:AUTHORS]->(album)
    MATCH (user:User {uid: '#{user_uid}'})
    OPTIONAL MATCH (user)-[heard:HEARD]->(song)
    RETURN song.name, song.order, album.name, author.name
    ORDER BY -heard.times DESC
    LIMIT #{length}
    """)
    |> Enum.map(&with_path/1)
  end

  def mark_song_for_user(conn, %{song: song}, uid) do
    conn
    |> Sips.query("""
    MATCH (user:User {uid: '#{uid}'})
    MATCH (song:Song {name: '#{song}'})
    MERGE (user)-[heard:HEARD]->(song)
    ON CREATE SET heard.times=1
    ON MATCH SET heard.times=(heard.times + 1)
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
