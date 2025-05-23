document.getElementById("awsForm").addEventListener("submit", async function (event) {
    event.preventDefault();

    const userId = document.getElementById("userId").value.trim();
    const ec2 = parseInt(document.getElementById("ec2").value);
    const ec2type = document.getElementById("ec2type").value;
    const s3 = parseInt(document.getElementById("s3").value);
    const rds = parseInt(document.getElementById("rds").value);

    try {
        const res = await fetch("https://www.jongseo22.com/aws_price_data.json");
        if (!res.ok) throw new Error(`HTTPS 오류: ${res.status}`);

        const pricing = await res.json();
        const summary = {};

        for (const [region, data] of Object.entries(pricing)) {
            const s3HourlyPerTB = (data.s3 ?? 0) / 730 * 1024;
            const total =
                (data.ec2?.[ec2type] ?? 0) * ec2 +
                s3HourlyPerTB * s3 +
                (data.rds ?? 0) * rds;
            summary[region] = parseFloat(total.toFixed(4));
        }

        const sorted = Object.entries(summary).sort((a, b) => a[1] - b[1]);
        const cheapest = sorted[0];
        const top3_region = sorted.slice(0, 3).map(([region]) => region);

        const titleWrapper = document.getElementById("topRegionTitleWrapper");
        titleWrapper.innerHTML = "";

        const title = document.createElement("h2");
        title.innerText = "Top 3 저렴한 리전";
        title.style.marginRight = "20px";
        titleWrapper.appendChild(title);

        const topRegionsDiv = document.createElement("div");
        topRegionsDiv.id = "topRegions";
        topRegionsDiv.style.display = "flex";
        topRegionsDiv.style.gap = "10px";

        const diagramWrapper = document.getElementById("diagramWrapper");

        sorted.slice(0, 3).forEach(([region, price]) => {
            const div = document.createElement("div");
            div.className = "region-item";
            div.innerText = `${region} ($${price})`;

            // 마우스 오버시 이미지 표시
            div.addEventListener("mouseenter", () => {
                diagramWrapper.innerHTML = "";

                const img = document.createElement("img");
                img.src = `/diagrams/${region}.png?t=${Date.now()}`;
                img.alt = `${region} 아키텍처 다이어그램`;
                img.className = "centered-image";

                diagramWrapper.appendChild(img);
            });

            div.addEventListener("mouseleave", () => {
                diagramWrapper.innerHTML = "";
            });

            // 클릭 시 next.html 이동
            div.addEventListener("click", () => {
                const query = new URLSearchParams();
		if (region) query.append("region", region);    
                if (userId) query.append("userId", userId);
                if (region) query.append("region", region);
                if (ec2) query.append("ec2", ec2);
                if (ec2type) query.append("ec2type", ec2type);
                if (s3) query.append("s3", s3);
                if (rds) query.append("rds", rds);

                window.location.href = `/next.html?${query.toString()}`;
            });

            topRegionsDiv.appendChild(div);
        });

        titleWrapper.appendChild(topRegionsDiv);

        let resultHTML = `<h2>최저가 리전: ${cheapest[0]} ($${cheapest[1]}/h)</h2>`;
        resultHTML += `<table>
        <thead>
          <tr>
            <th>리전</th>
            <th>EC2<br>(${ec2type}/시간)</th>
            <th>RDS<br>(t3.micro/시간)</th>
            <th>S3<br>(1TB/시간)</th>
            <th>총 비용<br>(시간)</th>
          </tr>
        </thead>
        <tbody>`;

        for (const [region, price] of Object.entries(summary)) {
            const ec2Unit = pricing[region].ec2?.[ec2type] ?? 0;
            const rdsUnit = pricing[region].rds ?? 0;
            const s3TBPerHour = (pricing[region].s3 ?? 0) / 730 * 1024;

            const highlight = top3_region.includes(region) ? 'highlight-row' : '';

            resultHTML += `<tr class="${highlight}">
              <td>${region}</td>
              <td>$${ec2Unit.toFixed(5)}</td>
              <td>$${rdsUnit.toFixed(5)}</td>
              <td>$${s3TBPerHour.toFixed(5)}</td>
              <td>$${price.toFixed(4)}</td>
            </tr>`;
        }

        resultHTML += '</tbody></table>';
        document.getElementById("output").innerHTML = resultHTML;

        await fetch("/save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ userId, ec2, ec2type, s3, rds, top3_region })
        });

    } catch (error) {
        document.getElementById("output").innerHTML = `<p style=\"color:red\">❗ 오류: ${error.message}</p>`;
    }
});

