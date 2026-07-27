using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

var keycloak = builder.Configuration.GetSection("Keycloak");

// -----------------------------------------------------------------------
// Milestone 4: this is the "downstream application" acting as an OpenID
// Connect Relying Party. It never sees a password -- it redirects the
// user to Keycloak, and trusts the signed JWT that comes back.
// -----------------------------------------------------------------------
builder.Services.AddAuthentication(options =>
{
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = OpenIdConnectDefaults.AuthenticationScheme;
})
.AddCookie()
.AddOpenIdConnect(options =>
{
    options.Authority = keycloak["Authority"];
    options.ClientId = keycloak["ClientId"];
    options.ClientSecret = keycloak["ClientSecret"];
    options.ResponseType = "code";               // Authorization Code flow
    options.UsePkce = true;
    options.SaveTokens = true;                    // keep tokens so we can inspect them
    options.GetClaimsFromUserInfoEndpoint = true;

    // Dev-only: Keycloak is running on plain HTTP on localhost.
    // In a real deployment, Keycloak MUST be served over HTTPS.
    options.RequireHttpsMetadata = false;

    options.Scope.Clear();
    options.Scope.Add("openid");
    options.Scope.Add("profile");
    options.Scope.Add("email");

    // Milestone 4: surface the custom "groups" claim added by our
    // group-membership protocol mapper into the local ClaimsPrincipal.
    options.ClaimActions.MapUniqueJsonKey("groups", "groups");

    options.TokenValidationParameters = new TokenValidationParameters
    {
        NameClaimType = "preferred_username",
        RoleClaimType = "groups"
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapRazorPages();

// Lightweight login/logout endpoints (Milestone 6: used for testing/validation)
app.MapGet("/Account/Login", async (HttpContext ctx) =>
{
    await ctx.ChallengeAsync(OpenIdConnectDefaults.AuthenticationScheme,
        new AuthenticationProperties { RedirectUri = "/" });
});

app.MapGet("/Account/Logout", async (HttpContext ctx) =>
{
    await ctx.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
    await ctx.SignOutAsync(OpenIdConnectDefaults.AuthenticationScheme,
        new AuthenticationProperties { RedirectUri = "/" });
});

app.Run();
