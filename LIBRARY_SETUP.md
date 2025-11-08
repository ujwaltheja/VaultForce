# JavaScript Library Setup Guide

## Quick Setup for Chart.js and ApexCharts

### Option 1: Using CDN Links (for development/testing)

You can load Chart.js and ApexCharts from CDN using the `platformResourceLoader` in LWC:

#### Chart.js CDN
```
https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js
```

#### ApexCharts CDN
```
https://cdn.jsdelivr.net/npm/apexcharts@3.45.0/dist/apexcharts.min.js
```

### Option 2: Download and Upload as Static Resources

#### Chart.js

1. **Download Chart.js**
   ```bash
   # Using npm
   npm install chart.js
   # File located at: node_modules/chart.js/dist/chart.umd.js

   # Or download directly from:
   https://github.com/chartjs/Chart.js/releases
   ```

2. **Copy to Static Resources**
   ```bash
   cp node_modules/chart.js/dist/chart.umd.js force-app/main/default/staticresources/chartjs.js
   ```

3. **Deploy**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/staticresources/chartjs.js -u your-org-alias
   ```

#### ApexCharts

1. **Download ApexCharts**
   ```bash
   # Using npm
   npm install apexcharts
   # File located at: node_modules/apexcharts/dist/apexcharts.min.js

   # Or download from:
   https://github.com/apexcharts/apexcharts.js/releases
   ```

2. **Copy to Static Resources**
   ```bash
   cp node_modules/apexcharts/dist/apexcharts.min.js force-app/main/default/staticresources/apexcharts.js
   ```

3. **Deploy**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/staticresources/apexcharts.js -u your-org-alias
   ```

### Option 3: All-in-One Script

Create a script to download and setup all libraries:

```bash
#!/bin/bash

# Create directories
mkdir -p force-app/main/default/staticresources

# Install libraries
npm install chart.js apexcharts

# Copy files
cp node_modules/chart.js/dist/chart.umd.js force-app/main/default/staticresources/chartjs.js
cp node_modules/apexcharts/dist/apexcharts.min.js force-app/main/default/staticresources/apexcharts.js

# Deploy to Salesforce
sfdx force:source:deploy -p force-app/main/default/staticresources -u your-org-alias

echo "✅ Libraries installed and deployed successfully!"
```

Save this as `setup-libraries.sh` and run:
```bash
chmod +x setup-libraries.sh
./setup-libraries.sh
```

## Usage in LWC Components

### Loading Chart.js in a Component

```javascript
import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import chartjs from '@salesforce/resourceUrl/chartjs';

export default class MyChartComponent extends LightningElement {
    chartjsInitialized = false;

    renderedCallback() {
        if (this.chartjsInitialized) {
            return;
        }
        this.chartjsInitialized = true;

        loadScript(this, chartjs)
            .then(() => {
                this.initializeChart();
            })
            .catch(error => {
                console.error('Error loading Chart.js', error);
            });
    }

    initializeChart() {
        const ctx = this.template.querySelector('canvas').getContext('2d');
        const myChart = new window.Chart(ctx, {
            type: 'bar',
            data: {
                labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May'],
                datasets: [{
                    label: 'Deployments',
                    data: [12, 19, 3, 5, 2],
                    backgroundColor: 'rgba(102, 126, 234, 0.5)',
                    borderColor: 'rgba(102, 126, 234, 1)',
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    }
}
```

### Loading ApexCharts in a Component

```javascript
import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import apexcharts from '@salesforce/resourceUrl/apexcharts';

export default class MyApexChartComponent extends LightningElement {
    apexchartsInitialized = false;

    renderedCallback() {
        if (this.apexchartsInitialized) {
            return;
        }
        this.apexchartsInitialized = true;

        loadScript(this, apexcharts)
            .then(() => {
                this.initializeChart();
            })
            .catch(error => {
                console.error('Error loading ApexCharts', error);
            });
    }

    initializeChart() {
        const options = {
            chart: {
                type: 'line',
                height: 350
            },
            series: [{
                name: 'Success Rate',
                data: [30, 40, 35, 50, 49, 60, 70, 91, 125]
            }],
            xaxis: {
                categories: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep']
            },
            colors: ['#667eea']
        };

        const chartElement = this.template.querySelector('.chart-container');
        const chart = new window.ApexCharts(chartElement, options);
        chart.render();
    }
}
```

## Recommended Charts for VaultForce

### Dashboard Component
- **Deployment Success Rate**: Line chart or area chart
- **Deployment Types**: Donut chart
- **Deployments Over Time**: Bar chart
- **Org Distribution**: Pie chart

### Deployment Manager
- **Progress Indicators**: Progress bars with ApexCharts
- **Timeline View**: Gantt-style chart
- **Success vs Failures**: Stacked bar chart

### Pipeline Board
- **Pipeline Flow**: Funnel chart
- **Stage Duration**: Horizontal bar chart
- **Artifact Count by Stage**: Column chart

## Sample Chart Configurations

### Success Rate Line Chart

```javascript
const successRateOptions = {
    chart: {
        type: 'line',
        height: 300,
        toolbar: { show: false }
    },
    series: [{
        name: 'Success Rate',
        data: deploymentData
    }],
    stroke: {
        curve: 'smooth',
        width: 3
    },
    colors: ['#10b981'],
    fill: {
        type: 'gradient',
        gradient: {
            shadeIntensity: 1,
            opacityFrom: 0.7,
            opacityTo: 0.3
        }
    },
    xaxis: {
        type: 'datetime'
    },
    yaxis: {
        labels: {
            formatter: (val) => val + '%'
        }
    }
};
```

### Deployment Types Donut Chart

```javascript
const donutOptions = {
    chart: {
        type: 'donut',
        height: 350
    },
    series: [44, 55, 13, 33],
    labels: ['Production', 'Sandbox', 'Developer', 'Scratch'],
    colors: ['#667eea', '#10b981', '#f59e0b', '#3b82f6'],
    legend: {
        position: 'bottom'
    },
    dataLabels: {
        enabled: true,
        formatter: (val) => val.toFixed(1) + '%'
    }
};
```

## Troubleshooting

### Library Not Loading

1. **Verify Static Resource**
   ```bash
   sfdx force:source:retrieve -m StaticResource:chartjs
   ```

2. **Check Console Errors**
   - Open browser DevTools
   - Check for CORS or loading errors

3. **Verify Meta XML**
   Ensure `chartjs.resource-meta.xml` exists with correct `contentType`

### Chart Not Rendering

1. **Check Container Element**
   ```javascript
   const element = this.template.querySelector('.chart-container');
   if (!element) {
       console.error('Chart container not found');
   }
   ```

2. **Verify Library Loaded**
   ```javascript
   if (typeof window.Chart === 'undefined') {
       console.error('Chart.js not loaded');
   }
   ```

3. **Check Dimensions**
   Ensure the container has explicit height/width

## Best Practices

1. **Load Once**: Only load libraries once per component lifecycle
2. **Error Handling**: Always catch loading errors
3. **Responsive**: Use responsive options for mobile compatibility
4. **Performance**: Destroy charts when component unmounts
5. **Theming**: Match chart colors with VaultForce design system

## Resources

- [Chart.js Documentation](https://www.chartjs.org/docs/)
- [ApexCharts Documentation](https://apexcharts.com/docs/)
- [Salesforce LWC Resource Loader](https://developer.salesforce.com/docs/component-library/bundle/lightning-platform-resource-loader/)
- [VaultForce UI Design System](./UI_MODERNIZATION_README.md)

---

**Note:** For production deployments, always test charts in a sandbox environment first.
