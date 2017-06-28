using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace GFT.DatabaseConnect.Web.Controllers
{
    public class HomeController : ApiController
    {
        public HomeController()
        {

        }

        public IHttpActionResult Get()
        {
            var output = string.Empty;
            var connString = ConfigurationManager.ConnectionStrings["AppConnString"].ConnectionString;
            using (var connection = new SqlConnection(connString))
            {
                try
                {
                    connection.Open();
                    output = "connected successfully";
                }
                catch
                {
                    output = "unable to connect";
                }
                
            }

            return Ok(output);
        }
    }
}
