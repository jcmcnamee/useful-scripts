param (
    [string]$SolutionName = $(Read-Host "Enter your solution name (must match the .sln file)"),
    [string[]]$Entities = $(Read-Host "Enter entity names separated by commas" -split ",\s*")
)

function New-ClassLibProject {
    param(
        [string]$ProjectName
    )
    dotnet new classlib -n $ProjectName
    dotnet sln add "$ProjectName/$ProjectName.csproj"
    $defaultClass = "$ProjectName/Class1.cs"
    if (Test-Path $defaultClass) {
        Remove-Item $defaultClass -Force
    }
}

function New-AspNetCoreProject {
    param(
        [string]$ProjectName
    )
    dotnet new web -n $ProjectName --no-https
    dotnet sln add "$ProjectName/$ProjectName.csproj"
    $defaultClass = "$ProjectName/Program.cs"
    if (Test-Path $defaultClass) {
        Remove-Item $defaultClass -Force
    }
}

# ========== DOMAIN ==========
$domainProj = "$SolutionName.Domain"
New-ClassLibProject $domainProj
New-Item -ItemType Directory -Path "$domainProj/Entities" -Force
New-Item -ItemType Directory -Path "$domainProj/Interfaces" -Force

foreach ($entity in $Entities) {
    $entityClass = @"
namespace $domainProj.Entities
{
    public class $entity
    {
        // Define properties
    }
}
"@
    Set-Content "$domainProj/Entities/$entity.cs" $entityClass
}

# ========== APPLICATION ==========
# Create project and project structure
$appProj = "$SolutionName.Application"
New-ClassLibProject $appProj
dotnet add "$appProj/$appProj.csproj" reference "$domainProj/$domainProj.csproj"

# Add project folders
$appFolders = @("Contracts", "Exceptions", "Extensions", "Features", "Profiles", "Responses", "Services", "Utilities")
foreach ($folder in $appFolders) {
    New-Item -ItemType Directory -Path "$appProj/$folder" -Force
}

# Add project NuGet packages
$appPackages = @(
    "AutoMapper",
    "FluentValidation",
    "MediatR",
    "Microsoft.Extensions.DependencyInjection"
)
foreach ($pkg in $appPackages) {
    dotnet add "$appProj/$appProj.csproj" package $pkg
}

# Add service registration
$services = "$appProj/ApplicationServiceRegistration.cs"
$servicesContent = @"
using Microsoft.Extensions.DependencyInjection;

namespace $appProj;
public static class ApplicationServiceRegistration
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddAutoMapper(AppDomain.CurrentDomain.GetAssemblies());
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblies(AppDomain.CurrentDomain.GetAssemblies()));

        return services;
    }
}
"@

Set-Content $services $servicesContent

# Add contracts
$contractPath = "$appProj/Contracts/Persistence"

New-Item -ItemType Directory -Path $contractPath -Force

$interface = "$appProj/Contracts/Persistence/IAsyncRepository.cs"
$interfaceContent = @"
namespace $appProj.Contracts.Persistence

public interface IAsyncRepository<T> where T : class
{
    Task<T> GetByIdAsync<TId>(TId id);
    Task<IReadOnlyList<T>> ListAllAsync();
    Task<T> AddAsync(T entity);
    Task UpdateAsync(T entity);
    Task DeleteAsync(T entity);
}

"@

Set-Content $interface $interfaceContent


# Create I{Entity}Service and {Entity}Service
# foreach ($entity in $Entities) {
#     $interfacePath = "$appProj/Services/I${entity}Service.cs"
#     $implPath = "$appProj/Services/${entity}Service.cs"

#     $interfaceContent = @"
# namespace $appProj.Services
# {
#     public interface I${entity}Service
#     {
#         // Define service methods
#     }
# }
# "@
#     $implContent = @"
# namespace $appProj.Services
# {
#     public class ${entity}Service : I${entity}Service
#     {
#         public ${entity}Service()
#         {
#             // Constructor logic
#         }

#         // Implement service methods
#     }
# }
# "@

#     Set-Content $interfacePath $interfaceContent
#     Set-Content $implPath $implContent
# }

# ========== PERSISTENCE ==========
$persistenceProj = "$SolutionName.Persistence"
New-ClassLibProject $persistenceProj
dotnet add "$persistenceProj/$persistenceProj.csproj" reference "$appProj/$appProj.csproj"

$persistenceFolders = @("Configuration", "Repositories", "Utilities")
foreach ($folder in $persistenceFolders) {
    New-Item -ItemType Directory -Path "$persistenceProj/$folder" -Force
}

$persistencePackages = @(
    "Microsoft.Extensions.Configuration",
    "Npgsql.EntityFrameworkCore.PostgreSQL"
)
foreach ($pkg in $persistencePackages) {
    dotnet add "$persistenceProj/$persistenceProj.csproj" package $pkg
}

# Create I{Entity}Repository and {Entity}Repository
foreach ($entity in $Entities) {
    $interfacePath = "$persistenceProj/Repositories/I${entity}Repository.cs"
    $implPath = "$persistenceProj/Repositories/${entity}Repository.cs"

    $interfaceContent = @"
namespace $persistenceProj.Repositories
{
    public interface I${entity}Repository
    {
        // Define repository methods
    }
}
"@
    $implContent = @"
namespace $persistenceProj.Repositories
{
    public class ${entity}Repository : I${entity}Repository
    {
        public ${entity}Repository()
        {
            // Constructor logic
        }

        // Implement repository methods
    }
}
"@
    Set-Content $interfacePath $interfaceContent
    Set-Content $implPath $implContent
}

# ========== INFRASTRUCTURE ==========
$infrastructureProj = "$SolutionName.Infrastructure"
New-ClassLibProject $infrastructureProj

# ========== API ==========
$apiProj = "$SolutionName.Api"
New-AspNetCoreProject $apiProj

dotnet add "$apiProj/$apiProj.csproj" reference "$appProj/$appProj.csproj"
dotnet add "$apiProj/$apiProj.csproj" reference "$persistenceProj/$persistenceProj.csproj"
dotnet add "$apiProj/$apiProj.csproj" reference "$infrastructureProj/$infrastructureProj.csproj"

New-Item -ItemType Directory -Path "$apiProj/Properties" -Force
New-Item -ItemType Directory -Path "$apiProj/Controllers" -Force

$apiPackages = @(
    "MediatR",
    "Microsoft.EntityFrameworkCore.Tools"
)
foreach ($pkg in $apiPackages) {
    dotnet add "$apiProj/$apiProj.csproj" package $pkg
}

Write-Host "`n✅ Clean Architecture project structure created with interfaces and services!"
