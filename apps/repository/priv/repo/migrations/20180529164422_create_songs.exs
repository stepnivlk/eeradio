defmodule Repository.Repo.Migrations.CreateSongs do
  use Ecto.Migration

  def change do
    create table(:songs) do
      add :name, :string
      add :album, :string
      add :author, :string
      add :file_type, :string
      add :bpm, :integer
      add :rating, :integer
      add :tags, {:array, :string}

      timestamps()
    end
  end
end
