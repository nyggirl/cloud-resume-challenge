const visitorCountElement = document.getElementById("visitor-count");

const visitorCounterApiUrl =
    "https://z8gd175yea.execute-api.us-east-2.amazonaws.com/visitor-count";

async function updateVisitorCount() {
    try {
        visitorCountElement.textContent = "Loading...";

        const response = await fetch(visitorCounterApiUrl);

        if (!response.ok) {
            throw new Error(`API request failed with status ${response.status}`);
        }

        const data = await response.json();

        visitorCountElement.textContent = data.count;
    } catch (error) {
        console.error("Unable to load visitor count:", error);
        visitorCountElement.textContent = "Unavailable";
    }
}

updateVisitorCount();