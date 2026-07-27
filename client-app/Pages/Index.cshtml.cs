using Microsoft.AspNetCore.Mvc.RazorPages;

namespace ZtnaApp.Pages;

public class IndexModel : PageModel
{
    // Which role-specific screen to render. Driven entirely by the "groups"
    // claim Keycloak put in the token -- this app never decides someone's
    // role itself, it only reads what the IdP already vouched for.
    public string? PrimaryGroup { get; private set; }

    public void OnGet()
    {
        PrimaryGroup = User.Claims
            .Where(c => c.Type == "groups")
            .Select(c => c.Value)
            .FirstOrDefault();
    }
}
