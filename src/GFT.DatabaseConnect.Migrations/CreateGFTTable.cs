using FluentMigrator;

namespace GFT.DatabaseConnect.Migrations
{
    [Migration(1)]
    public class CreateGFTTable : Migration
    {
        public override void Up()
        {
            Create.Table("GFT")
                .WithColumn("Id").AsInt64().PrimaryKey("PK_Gft")
                .WithColumn("Name").AsString().NotNullable()
                .WithColumn("Active").AsBoolean().NotNullable().WithDefaultValue(true);
        }

        public override void Down()
        {
            Delete.Table("GFT");
        }
    }
}
