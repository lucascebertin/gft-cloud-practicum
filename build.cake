#tool nuget:?package=FluentMigrator.Tools

#addin Cake.FluentMigrator

var target = Argument("target", "Default");
var configuration = Argument("configuration", "Release");
var dbHost = Argument("dbHost", "");
var dbName = Argument("dbName", "");
var dbUser = Argument("dbUser", "");
var dbPass = Argument("dbPass", "");


var solutionFile = GetFiles("./src/*.sln").First();
var solution = new Lazy<SolutionParserResult>(() => ParseSolution(solutionFile));
var distDir = Directory("./dist");
var buildDir = Directory("./build");

Task("Clean")
	.IsDependentOn("Clean-Outputs")
	.Does(() => 
	{
		DotNetBuild(solutionFile, settings => settings
			.SetConfiguration(configuration)
			.WithTarget("Clean")
			.SetVerbosity(Verbosity.Minimal));
	});

Task("Clean-Outputs")
	.Does(() => 
	{
		CleanDirectory(buildDir);
		CleanDirectory(distDir);
	});

Task("Build")
	.IsDependentOn("Clean-Outputs")
    .Does(() =>
	{
		NuGetRestore(solutionFile);

		DotNetBuild(solutionFile, settings => settings
			.SetConfiguration(configuration)
			.WithTarget("Rebuild")
			.SetVerbosity(Verbosity.Minimal));
    });
	
Task("Websites")
	.Does(() =>
	{
        NuGetRestore(solutionFile);
        
		var webProjects = solution.Value
			.Projects;

		foreach(var project in webProjects)
		{
			Information("Publishing {0}", project.Name);
			
			var publishDir = distDir + Directory(project.Name);

			DotNetBuild(project.Path, settings => settings
				.SetConfiguration(configuration)
				.WithProperty("DeployOnBuild", "true")
				.WithProperty("WebPublishMethod", "FileSystem")
				.WithProperty("DeployTarget", "WebPublish")
				.WithProperty("publishUrl", MakeAbsolute(publishDir).FullPath)
				.SetVerbosity(Verbosity.Minimal));

			Zip(publishDir, distDir + File(project.Name + ".zip"));
		}
	});
    
Task("Migrations")
    .IsDependentOn("Build")
	.Does(() =>{
        var outPath = MakeAbsolute(new FilePath("./fm-out.txt")).FullPath;
        Information("outPath = " + outPath);

        FluentMigrator(new FluentMigratorSettings
        {
            Connection = string.Format("Server={0};Database={1};User Id={2};Password={3};", dbHost, dbName, dbUser, dbPass),
            Provider = "SqlServer",
            Assembly = "./src/GFT.DatabaseConnect.Migrations/bin/Release/GFT.DatabaseConnect.Migrations.dll",
            Output = true,
            OutputFileName = outPath,
            PreviewOnly = false,
            Task = "migrate:up",
            Verbose = true,
            ApplicationContext = "GFT-Migrate"
        });
    });

Task("Default")
	.IsDependentOn("Websites");

RunTarget(target);