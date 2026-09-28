local delivery = require("dotnet-cli.commands.delivery")

describe("pack and publish commands", function()
  it("keeps pack options in structured argv", function()
    assert.are.same(
      {
        "dotnet",
        "pack",
        "src/My App/App.csproj",
        "-c",
        "Release",
        "-o",
        "artifacts/packages",
      },
      delivery.pack_cmd("src/My App/App.csproj", {
        configuration = "Release",
        output = "artifacts/packages",
      })
    )
  end)

  it(
    "supports profile, RID, self-contained and single-file publishing",
    function()
      assert.are.same(
        {
          "dotnet",
          "publish",
          "src/My App/App.csproj",
          "-c",
          "Release",
          "-p:PublishProfile=FolderProfile",
          "-r",
          "linux-x64",
          "--self-contained",
          "true",
          "-p:PublishSingleFile=true",
          "-o",
          "artifacts/publish",
        },
        delivery.publish_cmd("src/My App/App.csproj", {
          configuration = "Release",
          profile = "FolderProfile",
          runtime = "linux-x64",
          self_contained = true,
          single_file = true,
          output = "artifacts/publish",
        })
      )
    end
  )

  it(
    "builds item template creation with the selected output directory",
    function()
      assert.are.same({
        "dotnet",
        "new",
        "class",
        "--name",
        "Widget",
        "--output",
        "src/App",
      }, delivery.item_cmd("class", "Widget", "src/App"))
    end
  )
end)
