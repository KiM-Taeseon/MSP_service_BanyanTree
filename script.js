document.getElementById("awsForm").addEventListener("submit", async function (event) {
    event.preventDefault();

    const userId = document.getElementById("userId").value.trim();  // ✅ 추가
    const ec2 = parseInt(document.getElementById("ec2").value);
    const ec2type = document.getElementById("ec2type").value;
    const s3 = parseInt(document.getElementById("s3").value);
    const rds = parseInt(document.getElementById("rds").value);

    try {
        const res = await fetch("https://s3.ap-northeast-2.amazonaws.com/www.jongseo22.com/pricing/aws_price_data.json");

        if (!res.ok) {
            throw new Error(`HTTP 오류: ${res.status}`);
        }

        const pricing = await res.json();

        const summary = {};
        for (const [region, data] of Object.entries(pricing)) {
            const total =
                (data.ec2?.[ec2type] ?? 0) * ec2 +
                (data.s3 ?? 0) * s3 +
                (data.rds ?? 0) * rds;
            summary[region] = parseFloat(total.toFixed(4));
        }

        const sorted = Object.entries(summary).sort((a, b) => a[1] - b[1]);
        const cheapest = sorted[0];
        const top3_region = sorted.slice(0, 3).map(([region]) => region);

        const topRegionsDiv = document.getElementById("topRegions");
        topRegionsDiv.innerHTML = "<h2>📍 Top 3 저렴한 리전</h2>";

        sorted.slice(0, 3).forEach(([region, price]) => {
            const div = document.createElement("div");
            div.className = "region-item";
            div.innerText = `${region} ($${price})`;
            div.dataset.region = region;

            div.addEventListener("mouseenter", function () {
                const img = document.getElementById("diagramImage");
                img.src = `https://s3.ap-northeast-2.amazonaws.com/www.jongseo22.com/arch-${region}.png`;
            });

            div.addEventListener("mouseleave", function () {
                const img = document.getElementById("diagramImage");
                img.src = "https://s3.ap-northeast-2.amazonaws.com/www.jongseo22.com/multi-az_web_architecture.png";
            });

            topRegionsDiv.appendChild(div);
        });

        let resultHTML = `<h2>📍 최저가 리전: ${cheapest[0]} ($${cheapest[1]})</h2>`;
        resultHTML += `<table><thead><tr><th>리전</th><th>총 비용 ($)</th></tr></thead><tbody>`;
        for (const [region, price] of Object.entries(summary)) {
            resultHTML += `<tr><td>${region}</td><td>$${price}</td></tr>`;
        }
        resultHTML += '</tbody></table>';
        document.getElementById("output").innerHTML = resultHTML;

        // ✅ ID 포함해서 저장 요청
        await fetch("/save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ id: userId, ec2, ec2type, s3, rds, top3_region })
        });

    } catch (error) {
        document.getElementById("output").innerHTML = `<p style="color:red">❗ 오류: ${error.message}</p>`;
    }
});

